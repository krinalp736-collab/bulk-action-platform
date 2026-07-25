require "rails_helper"

RSpec.describe BulkActions::Create do
  def valid_attributes
    { account_id: "acc_test", entity_type: "Contact", action_type: "bulk_update",
      filter: { "status" => "lead" }, payload: { "status" => "active" } }
  end

  it "persists the bulk action as queued and enqueues the job immediately" do
    bulk_action = described_class.call(valid_attributes)

    expect(bulk_action).to be_persisted
    expect(bulk_action.status).to eq("queued")
    expect(BulkActionEnqueueJob.jobs.size).to eq(1)
    expect(BulkActionEnqueueJob.jobs.first["args"]).to eq([ bulk_action.id ])
  end

  it "persists as scheduled and schedules the job via perform_at instead of perform_async" do
    scheduled_at = 2.hours.from_now
    bulk_action = described_class.call(valid_attributes.merge(scheduled_at: scheduled_at))

    expect(bulk_action.status).to eq("scheduled")
    expect(BulkActionEnqueueJob.jobs.size).to eq(1)
    expect(BulkActionEnqueueJob.jobs.first["at"]).to be_within(1).of(scheduled_at.to_f)
  end

  it "does not save or enqueue anything for an invalid bulk action" do
    bulk_action = described_class.call(valid_attributes.merge(action_type: "nope"))

    expect(bulk_action).not_to be_persisted
    expect(bulk_action.errors).to be_present
    expect(BulkActionEnqueueJob.jobs).to be_empty
  end
end
