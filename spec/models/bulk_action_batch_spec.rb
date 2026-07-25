require "rails_helper"

RSpec.describe BulkActionBatch, type: :model do
  it "enforces a unique batch_number per bulk_action" do
    bulk_action = create(:bulk_action)
    create(:bulk_action_batch, bulk_action: bulk_action, batch_number: 1)

    duplicate = build(:bulk_action_batch, bulk_action: bulk_action, batch_number: 1)
    expect(duplicate).not_to be_valid
  end

  describe "#claim!" do
    it "transitions a pending batch to processing and returns true" do
      batch = create(:bulk_action_batch, status: "pending")
      expect(batch.claim!).to be(true)
      expect(batch.reload.status).to eq("processing")
    end

    it "allows re-claiming an already-processing batch (crash recovery)" do
      batch = create(:bulk_action_batch, status: "processing")
      expect(batch.claim!).to be(true)
    end

    it "refuses to claim an already-completed batch" do
      batch = create(:bulk_action_batch, status: "completed")
      expect(batch.claim!).to be(false)
    end
  end

  describe "#finalize!" do
    it "transitions to completed and returns true the first time" do
      batch = create(:bulk_action_batch, status: "processing")
      expect(batch.finalize!).to be(true)
      expect(batch.reload.status).to eq("completed")
    end

    it "returns false on a second call — exactly-once under redelivery" do
      batch = create(:bulk_action_batch, status: "processing")
      batch.finalize!

      expect(batch.finalize!).to be(false)
    end
  end
end
