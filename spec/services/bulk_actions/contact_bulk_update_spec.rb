require "rails_helper"

RSpec.describe BulkActions::ContactBulkUpdate do
  describe ".allowed_payload_keys" do
    it "whitelists exactly the safely-mass-assignable fields" do
      expect(described_class.allowed_payload_keys).to contain_exactly("name", "email", "age", "status")
    end
  end

  describe "#call" do
    it "applies only the whitelisted payload keys to the contact" do
      contact = create(:contact, status: "lead", name: "Original")
      strategy = described_class.new(payload: { "status" => "active", "account_id" => "ignored" })

      strategy.call(contact)

      expect(contact.reload.status).to eq("active")
      expect(contact.account_id).not_to eq("ignored")
    end

    it "raises ActiveRecord::RecordInvalid on bad data, leaving the row untouched" do
      contact = create(:contact, email: "original@example.com")
      strategy = described_class.new(payload: { "email" => "" })

      expect { strategy.call(contact) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(contact.reload.email).to eq("original@example.com")
    end
  end
end
