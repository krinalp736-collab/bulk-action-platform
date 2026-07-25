require "rails_helper"

RSpec.describe BulkActionEnqueueJob do
  around do |example|
    original = ENV["BULK_ACTION_BATCH_SIZE"]
    example.run
    ENV["BULK_ACTION_BATCH_SIZE"] = original
  end

  it "no-ops for a cancelled bulk action" do
    bulk_action = create(:bulk_action, :cancelled)

    described_class.new.perform(bulk_action.id)

    expect(bulk_action.reload.total_batches).to eq(0)
    expect(BulkActionBatchJob.jobs).to be_empty
  end

  it "immediately completes a bulk action whose target set is empty" do
    bulk_action = create(:bulk_action, account_id: "acc_empty", filter: { "status" => "lead" })

    described_class.new.perform(bulk_action.id)
    bulk_action.reload

    expect(bulk_action.status).to eq("completed")
    expect(bulk_action.total_count).to eq(0)
    expect(bulk_action.completed_at).to be_present
  end

  it "plans logs/batches, dedups by normalized email, and dispatches one job per batch" do
    kept = create(:contact, account_id: "acc_test", status: "lead", email: "same@example.com")
    other = create(:contact, account_id: "acc_test", status: "lead", email: "other@example.com")

    # A leading/trailing-whitespace duplicate can't be created through the
    # model (Contact's own format validation rejects it) — it only shows up
    # via a path that bypasses validations, like the CSV seed's insert_all.
    # Using insert_all here matches that real path and is what actually
    # exercises the TRIM() half of the dedup normalization.
    now = Time.current
    Contact.insert_all([ {
      account_id: "acc_test", name: "Dup", email: "  Same@Example.com  ", age: 30, status: "lead",
      created_at: now, updated_at: now
    } ])
    dup = Contact.find_by!(email: "  Same@Example.com  ")

    bulk_action = create(:bulk_action, account_id: "acc_test", filter: { "status" => "lead" })

    described_class.new.perform(bulk_action.id)
    bulk_action.reload

    expect(bulk_action.status).to eq("processing")
    expect(bulk_action.total_count).to eq(3)
    expect(bulk_action.skipped_count).to eq(1)
    expect(bulk_action.total_batches).to eq(1)
    expect(BulkActionBatchJob.jobs.size).to eq(1)

    expect(bulk_action.bulk_action_logs.pending.pluck(:entity_id)).to contain_exactly(kept.id, other.id)
    skipped_log = bulk_action.bulk_action_logs.skipped.find_by(entity_id: dup.id)
    expect(skipped_log.reason).to eq("duplicate email")
  end

  it "creates one batch per BULK_ACTION_BATCH_SIZE and dispatches all of them" do
    ENV["BULK_ACTION_BATCH_SIZE"] = "2"
    create_list(:contact, 5, account_id: "acc_test", status: "lead")
    bulk_action = create(:bulk_action, account_id: "acc_test", filter: { "status" => "lead" })

    described_class.new.perform(bulk_action.id)
    bulk_action.reload

    expect(bulk_action.total_batches).to eq(3) # 2 + 2 + 1
    expect(BulkActionBatchJob.jobs.size).to eq(3)
  end

  it "is safe to re-run after planning already committed, re-dispatching without re-planning" do
    create_list(:contact, 2, account_id: "acc_test", status: "lead")
    bulk_action = create(:bulk_action, account_id: "acc_test", filter: { "status" => "lead" })

    described_class.new.perform(bulk_action.id)
    bulk_action.reload
    first_total_count = bulk_action.total_count
    BulkActionBatchJob.jobs.clear

    described_class.new.perform(bulk_action.id)
    bulk_action.reload

    expect(bulk_action.total_count).to eq(first_total_count)
    expect(BulkActionBatchJob.jobs.size).to eq(1)
  end

  it "marks the bulk action failed and re-raises on an unexpected error" do
    bulk_action = create(:bulk_action, account_id: "acc_test", filter: { "status" => "lead" })
    allow(ContactsFilterQuery).to receive(:new).and_raise(StandardError, "boom")

    expect { described_class.new.perform(bulk_action.id) }.to raise_error(StandardError, "boom")
    expect(bulk_action.reload.status).to eq("failed")
    expect(bulk_action.error_message).to eq("boom")
  end
end
