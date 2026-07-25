require "rails_helper"

RSpec.describe BulkActions::ContactBulkArchive do
  it "needs no payload keys" do
    expect(described_class.allowed_payload_keys).to eq([])
  end

  it "sets the contact's status to archived regardless of payload" do
    contact = create(:contact, status: "active")

    described_class.new(payload: {}).call(contact)

    expect(contact.reload.status).to eq("archived")
  end
end
