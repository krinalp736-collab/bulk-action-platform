class BulkActionLog < ApplicationRecord
  belongs_to :bulk_action
  belongs_to :bulk_action_batch, optional: true

  enum :status, { pending: 0, success: 1, failed: 2, skipped: 3 },
       default: "pending", validate: true

  validates :entity_type, presence: true
  validates :entity_id, presence: true

  scope :with_status, ->(status) { status.present? ? where(status: status) : all }
  scope :after, ->(cursor_id) { cursor_id.present? ? where("bulk_action_logs.id > ?", cursor_id) : all }
  scope :ordered, -> { order(:id) }

  def mark_success!
    transition_from_pending!(status: self.class.statuses[:success], processed_at: Time.current)
  end

  def mark_failed!(reason)
    transition_from_pending!(status: self.class.statuses[:failed], reason: reason.to_s.truncate(1000), processed_at: Time.current)
  end

  private

  # Guards every transition on `WHERE status = pending`, so a Sidekiq retry
  # replaying an already-finished row is a no-op instead of double-counting
  # it on the parent bulk_action's success/failed counters.
  def transition_from_pending!(attrs)
    updated = self.class.where(id: id, status: self.class.statuses[:pending]).update_all(attrs)
    reload if updated.positive?
    updated.positive?
  end
end
