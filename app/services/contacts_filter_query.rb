# Turns a BulkAction's `filter` or `contact_ids` into a Contact relation.
# Always anchors on the bulk action's account_id BEFORE merging any
# client-supplied filter — a client can never widen or escape tenant scoping
# by what it puts in `filter` (any account_id key in there is rejected as an
# unsupported filter key, never merged in).
class ContactsFilterQuery
  InvalidFilterError = Class.new(StandardError)

  ALLOWED_FILTER_KEYS = %w[status age name email].freeze

  # Pure key-whitelist check, no DB access — reused by BulkAction's own
  # validation so an unsupported filter key is rejected with a 422 at
  # creation time, not discovered later when the background job runs it.
  def self.validate_keys!(filter)
    return if filter.blank?

    unknown_keys = filter.keys.map(&:to_s) - ALLOWED_FILTER_KEYS
    return if unknown_keys.empty?

    raise InvalidFilterError, "unsupported filter keys: #{unknown_keys.join(', ')}"
  end

  def initialize(bulk_action)
    @bulk_action = bulk_action
  end

  # Does NOT apply a snapshot boundary — callers that need the target set
  # frozen in time (BulkActionEnqueueJob) should further scope by
  # `where(id: ..snapshot_max_id)` once that id has been captured.
  def relation
    scope = Contact.where(account_id: bulk_action.account_id)
    bulk_action.contact_ids.present? ? scope.where(id: bulk_action.contact_ids) : apply_filter(scope)
  end

  private

  attr_reader :bulk_action

  def apply_filter(scope)
    filter = bulk_action.filter
    return scope if filter.blank?

    self.class.validate_keys!(filter)
    scope.where(filter.slice(*ALLOWED_FILTER_KEYS))
  end
end
