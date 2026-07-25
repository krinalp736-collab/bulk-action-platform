require "rails_helper"

RSpec.describe BulkAction, type: :model do
  it "is valid with valid attributes" do
    expect(build(:bulk_action)).to be_valid
  end

  it "is valid for a second registered strategy with no payload" do
    expect(build(:bulk_action, :bulk_archive, filter: { "status" => "inactive" })).to be_valid
  end

  describe "presence validations" do
    it { expect(build(:bulk_action, account_id: nil)).not_to be_valid }
    it { expect(build(:bulk_action, entity_type: nil)).not_to be_valid }
    it { expect(build(:bulk_action, action_type: nil)).not_to be_valid }
  end

  describe "action_type_is_registered" do
    it "rejects an action_type with no registered strategy" do
      bulk_action = build(:bulk_action, action_type: "bulk_teleport")
      expect(bulk_action).not_to be_valid
      expect(bulk_action.errors[:action_type]).to be_present
    end
  end

  describe "payload_keys_are_allowed" do
    it "rejects payload keys outside the strategy's whitelist" do
      bulk_action = build(:bulk_action, payload: { "status" => "active", "account_id" => "hijack" })
      expect(bulk_action).not_to be_valid
      expect(bulk_action.errors[:payload].join).to include("account_id")
    end

    it "accepts an empty payload for an action that needs none" do
      bulk_action = build(:bulk_action, :bulk_archive, filter: {})
      expect(bulk_action).to be_valid
    end
  end

  describe "targeting_is_unambiguous" do
    it "rejects specifying both filter and contact_ids" do
      bulk_action = build(:bulk_action, filter: { "status" => "lead" }, contact_ids: [ 1, 2 ])
      expect(bulk_action).not_to be_valid
      expect(bulk_action.errors[:base].join).to match(/filter.*contact_ids/)
    end

    it "accepts filter alone" do
      expect(build(:bulk_action, filter: { "status" => "lead" }, contact_ids: nil)).to be_valid
    end

    it "accepts contact_ids alone" do
      expect(build(:bulk_action, :targeting_ids, contact_ids: [ 1, 2, 3 ])).to be_valid
    end
  end

  describe "contact_ids_within_limit" do
    it "rejects more than MAX_CONTACT_IDS ids" do
      too_many = Array.new(described_class::MAX_CONTACT_IDS + 1) { |i| i }
      bulk_action = build(:bulk_action, :targeting_ids, contact_ids: too_many)
      expect(bulk_action).not_to be_valid
      expect(bulk_action.errors[:contact_ids]).to be_present
    end

    it "accepts exactly MAX_CONTACT_IDS ids" do
      exactly_max = Array.new(described_class::MAX_CONTACT_IDS) { |i| i }
      expect(build(:bulk_action, :targeting_ids, contact_ids: exactly_max)).to be_valid
    end
  end

  describe "filter_keys_are_valid" do
    it "rejects an unsupported filter key" do
      bulk_action = build(:bulk_action, filter: { "account_id" => "acc_other" })
      expect(bulk_action).not_to be_valid
      expect(bulk_action.errors[:filter].join).to include("account_id")
    end
  end

  describe "scheduled_at_not_in_past" do
    it "rejects a scheduled_at in the past" do
      expect(build(:bulk_action, scheduled_at: 1.hour.ago)).not_to be_valid
    end

    it "accepts a scheduled_at in the future" do
      expect(build(:bulk_action, :scheduled)).to be_valid
    end
  end

  describe "#processed_count" do
    it "sums success, failed, and skipped" do
      bulk_action = build(:bulk_action, success_count: 3, failed_count: 2, skipped_count: 1)
      expect(bulk_action.processed_count).to eq(6)
    end
  end

  describe "#percentage_complete" do
    it "is 0 when total_count is zero" do
      expect(build(:bulk_action, total_count: 0).percentage_complete).to eq(0.0)
    end

    it "computes processed/total as a percentage" do
      bulk_action = build(:bulk_action, total_count: 4, success_count: 1, failed_count: 1)
      expect(bulk_action.percentage_complete).to eq(50.0)
    end
  end

  describe "#cancellable? / #cancel!" do
    it "is cancellable while queued, scheduled, or processing" do
      expect(create(:bulk_action, status: "queued")).to be_cancellable
      expect(create(:bulk_action, :scheduled)).to be_cancellable
      expect(create(:bulk_action, :processing)).to be_cancellable
    end

    it "is not cancellable once completed, failed, or cancelled" do
      expect(create(:bulk_action, :completed)).not_to be_cancellable
      expect(create(:bulk_action, status: "failed")).not_to be_cancellable
      expect(create(:bulk_action, :cancelled)).not_to be_cancellable
    end

    it "transitions a cancellable bulk action to cancelled" do
      bulk_action = create(:bulk_action, :processing)
      expect(bulk_action.cancel!).to be(true)
      expect(bulk_action.reload.status).to eq("cancelled")
    end

    it "refuses to cancel a completed bulk action" do
      bulk_action = create(:bulk_action, :completed)
      expect(bulk_action.cancel!).to be(false)
      expect(bulk_action.reload.status).to eq("completed")
    end
  end

  describe "#strategy_class" do
    it "resolves to the registered strategy" do
      expect(build(:bulk_action).strategy_class).to eq(BulkActions::ContactBulkUpdate)
    end
  end
end
