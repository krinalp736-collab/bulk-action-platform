# Plans and dispatches one BulkAction. Deliberately a plain Sidekiq::Job
# (not ActiveJob) so we can use perform_at/perform_in directly for
# scheduling, per the Sidekiq OSS native scheduling approach this system
# relies on instead of a separate scheduler gem.
#
# Two phases, run sequentially in one invocation:
#
#   1. PLAN (wrapped in one transaction: all-or-nothing, so a crash mid-plan
#      leaves no partial state to conflict with a clean retry) — resolve the
#      target Contact set, freeze it with a snapshot max id, de-duplicate by
#      email in a single set-based SQL statement, and group the survivors
#      into bulk_action_batches. total_batches/total_count are written ONCE,
#      atomically, after every batch row already exists — no
#      BulkActionBatchJob is enqueued until this commits, so no worker can
#      ever observe completed_batches == total_batches before total_batches
#      is final.
#   2. DISPATCH — enqueue a BulkActionBatchJob per batch row.
#
# Splitting them this way (rather than streaming-enqueue-as-you-go) is what
# makes the whole job idempotent: if status is already `processing` when
# this runs (a Sidekiq redelivery after phase 1 committed but phase 2 didn't
# finish), planning is skipped and only dispatch re-runs — safe, since
# BulkActionBatchJob's own claim!/finalize! guards make redundant dispatch a
# no-op.
class BulkActionEnqueueJob
  include Sidekiq::Job

  sidekiq_options queue: :bulk_action_enqueue, retry: 5

  def perform(bulk_action_id)
    bulk_action = BulkAction.find(bulk_action_id)
    return if bulk_action.cancelled?

    plan!(bulk_action) if bulk_action.queued? || bulk_action.scheduled?
    dispatch!(bulk_action) if bulk_action.processing?
  rescue StandardError => e
    bulk_action&.update!(status: :failed, error_message: e.message)
    raise
  end

  private

  def plan!(bulk_action)
    contact_scope = ContactsFilterQuery.new(bulk_action).relation
    snapshot_max_id = contact_scope.maximum(:id)

    ActiveRecord::Base.transaction do
      if snapshot_max_id.nil?
        finalize_empty_run!(bulk_action)
        next
      end

      scoped = contact_scope.where(id: ..snapshot_max_id)
      insert_logs_with_dedup!(bulk_action, scoped)

      skipped_count = bulk_action.bulk_action_logs.skipped.count
      pending_count = bulk_action.bulk_action_logs.pending.count
      batch_count = create_batches!(bulk_action, pending_count)

      bulk_action.update!(
        status: batch_count.zero? ? :completed : :processing,
        snapshot_max_id: snapshot_max_id,
        total_count: skipped_count + pending_count,
        skipped_count: skipped_count,
        total_batches: batch_count,
        started_at: Time.current,
        completed_at: (Time.current if batch_count.zero?)
      )
    end
  end

  def finalize_empty_run!(bulk_action)
    bulk_action.update!(
      status: :completed, total_count: 0, snapshot_max_id: nil,
      started_at: Time.current, completed_at: Time.current
    )
  end

  # One set-based INSERT...SELECT: computes email de-duplication globally
  # and deterministically (lowest id per normalized email wins — no race
  # between concurrently-running batches) and writes a bulk_action_logs row
  # for every target in the same statement. `scoped.to_sql` is safe to embed
  # because ActiveRecord/the pg adapter already quotes every value in that
  # relation's WHERE clause — this is not raw string interpolation of
  # client input, just composing two already-safe SQL fragments.
  def insert_logs_with_dedup!(bulk_action, scoped_contacts)
    quoted_entity_type = ActiveRecord::Base.connection.quote(bulk_action.entity_type)
    quoted_now = ActiveRecord::Base.connection.quote(Time.current)
    inner_sql = scoped_contacts.select(:id, :email).to_sql

    sql = <<~SQL
      INSERT INTO bulk_action_logs (bulk_action_id, entity_type, entity_id, status, reason, created_at)
      SELECT #{bulk_action.id}, #{quoted_entity_type}, id,
             CASE WHEN rn = 1 THEN #{BulkActionLog.statuses[:pending]} ELSE #{BulkActionLog.statuses[:skipped]} END,
             CASE WHEN rn > 1 THEN 'duplicate email' END,
             #{quoted_now}
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY id) AS rn
        FROM (#{inner_sql}) AS targeted_contacts
      ) AS ranked
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  # Only ever holds `batch_size` ids in memory at a time, however large the
  # target set is.
  def create_batches!(bulk_action, pending_count)
    return 0 if pending_count.zero?

    batch_size = ENV.fetch("BULK_ACTION_BATCH_SIZE", 1000).to_i
    batch_number = 0

    bulk_action.bulk_action_logs.pending.find_in_batches(batch_size: batch_size) do |group|
      batch_number += 1
      batch = bulk_action.bulk_action_batches.create!(batch_number: batch_number)
      BulkActionLog.where(id: group.map(&:id)).update_all(bulk_action_batch_id: batch.id)
    end

    batch_number
  end

  def dispatch!(bulk_action)
    bulk_action.bulk_action_batches.where(status: %w[pending processing]).find_each do |batch|
      BulkActionBatchJob.perform_async(batch.id)
    end
  end
end
