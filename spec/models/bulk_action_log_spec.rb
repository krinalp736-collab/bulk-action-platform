require "rails_helper"

RSpec.describe BulkActionLog, type: :model do
  it "enforces a unique entity_id per bulk_action at the database level" do
    # No app-level uniqueness validation is declared: these rows are only
    # ever created by our own controlled SQL/insert_all during planning, never
    # from user input, so the DB constraint alone is the right guard — this
    # spec exercises that constraint directly rather than #valid?.
    bulk_action = create(:bulk_action)
    create(:bulk_action_log, bulk_action: bulk_action, entity_id: 5)

    duplicate = build(:bulk_action_log, bulk_action: bulk_action, entity_id: 5)
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "#mark_success!" do
    it "transitions a pending log to success and returns true" do
      log = create(:bulk_action_log, status: "pending")
      expect(log.mark_success!).to be(true)
      expect(log.reload).to be_success
      expect(log.processed_at).to be_present
    end

    it "returns false and leaves the row untouched if not pending (retry-safety)" do
      log = create(:bulk_action_log, status: "success", reason: nil)
      expect(log.mark_success!).to be(false)
      expect(log.reload).to be_success
    end
  end

  describe "#mark_failed!" do
    it "transitions a pending log to failed with a reason" do
      log = create(:bulk_action_log, status: "pending")
      expect(log.mark_failed!("boom")).to be(true)
      log.reload
      expect(log).to be_failed
      expect(log.reason).to eq("boom")
    end

    it "is a no-op once already terminal (retry-safety)" do
      log = create(:bulk_action_log, status: "failed", reason: "original")
      expect(log.mark_failed!("different reason")).to be(false)
      expect(log.reload.reason).to eq("original")
    end

    it "truncates an overly long reason" do
      log = create(:bulk_action_log, status: "pending")
      log.mark_failed!("x" * 2000)
      expect(log.reload.reason.length).to eq(1000)
    end
  end

  describe "scopes" do
    it ".with_status filters by status when given, otherwise passes through" do
      pending_log = create(:bulk_action_log, status: "pending")
      failed_log = create(:bulk_action_log, status: "failed")

      expect(BulkActionLog.with_status("failed")).to contain_exactly(failed_log)
      expect(BulkActionLog.with_status(nil)).to contain_exactly(pending_log, failed_log)
    end

    it ".after applies keyset pagination" do
      first = create(:bulk_action_log)
      second = create(:bulk_action_log)

      expect(BulkActionLog.after(first.id)).to contain_exactly(second)
      expect(BulkActionLog.after(nil)).to contain_exactly(first, second)
    end
  end
end
