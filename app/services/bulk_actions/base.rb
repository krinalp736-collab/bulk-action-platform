module BulkActions
  # Every concrete bulk action (ContactBulkUpdate, ContactBulkArchive, and
  # anything added later — delete/email/export/assign/...) implements this
  # interface. BulkActionBatchJob only ever talks to this interface, so a new
  # action is "write one class + register it" with zero changes to the job
  # pipeline, controllers, or models.
  class Base
    # Raised by a strategy for an expected, per-entity business failure (bad
    # data, a domain rule violation, etc). BulkActionBatchJob rescues this and
    # records the row as `failed` without aborting the rest of the batch.
    # Anything else (a raised infra error) is left to propagate so Sidekiq's
    # job-level retry can take over the whole batch.
    class BusinessError < StandardError; end

    # Payload keys this action accepts from the client, e.g. %w[name email
    # age status] for an update. Empty for actions that need no payload
    # (archive, delete). Enforced by BulkAction's payload validation so a
    # client can't mass-assign arbitrary fields through a generic jsonb column.
    def self.allowed_payload_keys
      []
    end

    def initialize(payload: {})
      @payload = payload || {}
    end

    # Applies this action to a single entity. Must raise BusinessError (or an
    # ActiveRecord::RecordInvalid) on a per-entity failure that should be
    # logged and skipped rather than aborting the batch.
    def call(entity)
      raise NotImplementedError, "#{self.class} must implement #call(entity)"
    end

    private

    attr_reader :payload
  end
end
