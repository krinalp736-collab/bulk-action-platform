# Processes one bulk_action_batch's worth of entities. Plain Sidekiq::Job
# (see BulkActionEnqueueJob for why) using perform_in for rate-limit
# backoff.
#
# Safe under Sidekiq's at-least-once redelivery because every state
# transition here is a conditional UPDATE guarded on the row's current
# status (BulkActionBatch#claim!/#finalize!, BulkActionLog#mark_success!/
# #mark_failed!) — a retry after a crash only ever touches rows the
# previous attempt didn't finish, and counters are incremented by the
# actual delta this invocation produced, never by a static batch size.
class BulkActionBatchJob
  include Sidekiq::Job

  sidekiq_options queue: :bulk_action_batch, retry: 5

  RATE_LIMIT_JITTER = 0..5

  def perform(bulk_action_batch_id)
    batch = BulkActionBatch.find(bulk_action_batch_id)
    bulk_action = batch.bulk_action
    return if bulk_action.cancelled?
    return unless batch.claim!

    pending_logs = batch.bulk_action_logs.pending.order(:id).to_a
    unless RateLimiter.new(bulk_action.account_id).allow?(pending_logs.size)
      requeue_for_rate_limit!(batch)
      return
    end

    success_delta, failed_delta = process_rows!(bulk_action, pending_logs)
    if success_delta.positive? || failed_delta.positive?
      BulkAction.update_counters(bulk_action.id, success_count: success_delta, failed_count: failed_delta)
    end

    finalize_batch_and_maybe_parent!(batch, bulk_action)
  end

  private

  def process_rows!(bulk_action, pending_logs)
    strategy = bulk_action.strategy_class.new(payload: bulk_action.payload)
    contacts_by_id = Contact.where(id: pending_logs.map(&:entity_id)).index_by(&:id)

    success_delta = 0
    failed_delta = 0

    pending_logs.each do |log|
      contact = contacts_by_id[log.entity_id]

      if contact.nil?
        failed_delta += 1 if log.mark_failed!("entity no longer exists")
        next
      end

      begin
        ActiveRecord::Base.transaction { strategy.call(contact) }
        success_delta += 1 if log.mark_success!
      rescue ActiveRecord::RecordInvalid, BulkActions::Base::BusinessError => e
        failed_delta += 1 if log.mark_failed!(e.message)
      end
      # Anything else (PG::ConnectionBad, Redis timeouts, ...) is left to
      # propagate so Sidekiq's retry reruns the batch — see class comment.
    end

    [ success_delta, failed_delta ]
  end

  def finalize_batch_and_maybe_parent!(batch, bulk_action)
    return unless batch.finalize!

    BulkAction.where(id: bulk_action.id).update_all("completed_batches = completed_batches + 1")
    bulk_action.reload

    return unless bulk_action.completed_batches >= bulk_action.total_batches

    BulkAction.where(id: bulk_action.id).where.not(status: BulkAction.statuses[:completed])
              .update_all(status: BulkAction.statuses[:completed], completed_at: Time.current)
  end

  def requeue_for_rate_limit!(batch)
    delay = RateLimiter.seconds_until_next_window + rand(RATE_LIMIT_JITTER)
    BulkActionBatchJob.perform_in(delay, batch.id)
  end
end
