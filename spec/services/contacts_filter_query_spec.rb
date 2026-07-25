require "rails_helper"

RSpec.describe ContactsFilterQuery do
  describe ".validate_keys!" do
    it "does not raise for a blank filter" do
      expect { described_class.validate_keys!({}) }.not_to raise_error
      expect { described_class.validate_keys!(nil) }.not_to raise_error
    end

    it "does not raise for whitelisted keys" do
      expect { described_class.validate_keys!("status" => "lead", "age" => 30) }.not_to raise_error
    end

    it "raises InvalidFilterError for an unsupported key" do
      expect { described_class.validate_keys!("account_id" => "other") }
        .to raise_error(described_class::InvalidFilterError, /account_id/)
    end
  end

  describe "#relation" do
    it "always scopes to the bulk action's account_id" do
      mine = create(:contact, account_id: "acc_a", status: "lead")
      create(:contact, account_id: "acc_b", status: "lead")
      bulk_action = build(:bulk_action, account_id: "acc_a", filter: { "status" => "lead" })

      expect(described_class.new(bulk_action).relation).to contain_exactly(mine)
    end

    it "applies whitelisted filter keys as equality conditions" do
      lead = create(:contact, account_id: "acc_a", status: "lead")
      create(:contact, account_id: "acc_a", status: "active")
      bulk_action = build(:bulk_action, account_id: "acc_a", filter: { "status" => "lead" })

      expect(described_class.new(bulk_action).relation).to contain_exactly(lead)
    end

    it "targets contact_ids directly when given, ignoring filter" do
      a = create(:contact, account_id: "acc_a", status: "lead")
      b = create(:contact, account_id: "acc_a", status: "active")
      bulk_action = build(:bulk_action, :targeting_ids, account_id: "acc_a", contact_ids: [ a.id, b.id ])

      expect(described_class.new(bulk_action).relation).to contain_exactly(a, b)
    end

    it "never lets contact_ids from another account leak in" do
      mine = create(:contact, account_id: "acc_a")
      other = create(:contact, account_id: "acc_b")
      bulk_action = build(:bulk_action, :targeting_ids, account_id: "acc_a", contact_ids: [ mine.id, other.id ])

      expect(described_class.new(bulk_action).relation).to contain_exactly(mine)
    end

    it "raises InvalidFilterError for an unsupported filter key" do
      bulk_action = build(:bulk_action, account_id: "acc_a", filter: { "account_id" => "acc_b" })

      expect { described_class.new(bulk_action).relation }.to raise_error(described_class::InvalidFilterError)
    end
  end
end
