module BulkActions
  # Second concrete strategy, deliberately included even though only Bulk
  # Update was required: it proves the Strategy/Registry pattern actually
  # delivers on "add a new bulk action without touching existing code" —
  # this file and one Registry line are the entire diff.
  class ContactBulkArchive < Base
    def call(contact)
      contact.update!(status: "archived")
    end
  end
end
