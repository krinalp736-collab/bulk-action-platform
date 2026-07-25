class BulkActionBatch < ApplicationRecord
  belongs_to :bulk_action
  has_many :bulk_action_logs

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 },
       default: "pending", validate: true

  validates :batch_number, presence: true, uniqueness: { scope: :bulk_action_id }

  # Claims this batch for work. Returns true only for the call that actually
  # transitions it, so a Sidekiq redelivery after a crash mid-batch re-claims
  # cleanly instead of racing a still-running attempt.
  def claim!
    updated = self.class
      .where(id: id, status: %w[pending processing])
      .update_all(status: self.class.statuses[:processing], started_at: started_at || Time.current, updated_at: Time.current)
    reload if updated.positive?
    updated.positive?
  end

  # Marks the batch completed exactly once. Returns true only for the
  # invocation that flips it, so the parent bulk_action's completed_batches
  # counter can never be double-incremented by a redelivered job.
  def finalize!
    updated = self.class
      .where(id: id)
      .where.not(status: self.class.statuses[:completed])
      .update_all(status: self.class.statuses[:completed], completed_at: Time.current, updated_at: Time.current)
    reload if updated.positive?
    updated.positive?
  end
end
