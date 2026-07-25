class BulkAction < ApplicationRecord
  MAX_CONTACT_IDS = ENV.fetch("BULK_ACTION_MAX_CONTACT_IDS", 10_000).to_i
  CANCELLABLE_STATUSES = %w[scheduled queued processing].freeze

  enum :status, { queued: 0, scheduled: 1, processing: 2, completed: 3, failed: 4, cancelled: 5 },
       default: "queued", validate: true

  has_many :bulk_action_batches, dependent: :destroy
  has_many :bulk_action_logs, dependent: :destroy

  validates :account_id, presence: true
  validates :entity_type, presence: true
  validates :action_type, presence: true

  validate :action_type_is_registered
  validate :payload_keys_are_allowed
  validate :targeting_is_unambiguous
  validate :contact_ids_within_limit
  validate :filter_keys_are_valid
  validate :scheduled_at_not_in_past

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  # success/failed/skipped are mutually exclusive terminal states for a given
  # entity, so the total processed so far is just their sum — deliberately
  # not a stored column, so there's only ever one source of truth to update.
  def processed_count
    success_count + failed_count + skipped_count
  end

  def percentage_complete
    return 0.0 if total_count.zero?

    ((processed_count.to_f / total_count) * 100).round(2)
  end

  def cancellable?
    status.in?(CANCELLABLE_STATUSES)
  end

  def cancel!
    return false unless cancellable?

    update!(status: :cancelled)
  end

  def strategy_class
    BulkActions::Registry.resolve(entity_type, action_type)
  end

  private

  def action_type_is_registered
    return if entity_type.blank? || action_type.blank?

    unless BulkActions::Registry.registered?(entity_type, action_type)
      errors.add(:action_type, "is not a registered bulk action for entity #{entity_type}")
    end
  end

  def payload_keys_are_allowed
    return if payload.blank?
    return unless BulkActions::Registry.registered?(entity_type, action_type)

    allowed = strategy_class.allowed_payload_keys.map(&:to_s)
    disallowed = payload.keys.map(&:to_s) - allowed
    return if disallowed.empty?

    errors.add(:payload, "contains unsupported keys for #{action_type}: #{disallowed.join(', ')}")
  end

  def targeting_is_unambiguous
    return if contact_ids.blank? || filter.blank?

    errors.add(:base, "specify either `filter` or `contact_ids`, not both")
  end

  def contact_ids_within_limit
    return if contact_ids.blank?

    return unless contact_ids.size > MAX_CONTACT_IDS

    errors.add(:contact_ids, "may include at most #{MAX_CONTACT_IDS} ids — use `filter` to target more than that")
  end

  def scheduled_at_not_in_past
    return if scheduled_at.blank?

    errors.add(:scheduled_at, "can't be in the past") if scheduled_at < Time.current
  end

  # Rejects an unsupported filter key at creation time (422) instead of only
  # discovering it later when BulkActionEnqueueJob runs the same check.
  def filter_keys_are_valid
    ContactsFilterQuery.validate_keys!(filter)
  rescue ContactsFilterQuery::InvalidFilterError => e
    errors.add(:filter, e.message)
  end
end
