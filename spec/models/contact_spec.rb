require "rails_helper"

RSpec.describe Contact, type: :model do
  it "is valid with valid attributes" do
    expect(build(:contact)).to be_valid
  end

  it "requires an account_id" do
    expect(build(:contact, account_id: nil)).not_to be_valid
  end

  it "requires a name" do
    expect(build(:contact, name: nil)).not_to be_valid
  end

  it "requires a well-formed email" do
    contact = build(:contact, email: "not-an-email")
    expect(contact).not_to be_valid
    expect(contact.errors[:email]).to be_present
  end

  it "rejects a blank email" do
    expect(build(:contact, email: "")).not_to be_valid
  end

  it "defaults status to lead" do
    expect(Contact.new.status).to eq("lead")
  end

  it "rejects an unrecognized status" do
    # String-backed enum with validate: true: an unmapped value is a
    # validation failure, not an immediate raise (that's integer-enum
    # behavior) — it's stored as-is and caught by #valid?.
    contact = build(:contact, status: "bogus")
    expect(contact).not_to be_valid
    expect(contact.errors[:status]).to be_present
  end

  describe ".for_account" do
    it "scopes to the given account_id" do
      mine = create(:contact, account_id: "acc_a")
      create(:contact, account_id: "acc_b")

      expect(Contact.for_account("acc_a")).to contain_exactly(mine)
    end
  end
end
