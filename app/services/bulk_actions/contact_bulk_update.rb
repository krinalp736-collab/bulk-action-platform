module BulkActions
  # Applies the same set of field changes to every targeted Contact — a CRM
  # "select all matching X, set field to Y" bulk edit. All entities in a run
  # share one payload; per-row differing updates would be a distinct feature
  # (CSV import/upsert) intentionally out of scope here.
  class ContactBulkUpdate < Base
    def self.allowed_payload_keys
      %w[name email age status]
    end

    def call(contact)
      # update! raises ActiveRecord::RecordInvalid on bad data (e.g. a
      # malformed email) — one of the two error types BulkActionBatchJob
      # treats as a per-row business failure rather than an infra failure.
      contact.update!(payload.slice(*self.class.allowed_payload_keys))
    end
  end
end
