require "rails_helper"

RSpec.describe BulkActionBatchJob do
  def setup_batch(bulk_action:, contacts:)
    batch = create(:bulk_action_batch, bulk_action: bulk_action, batch_number: 1)
    contacts.each do |contact|
      create(:bulk_action_log, bulk_action: bulk_action, bulk_action_batch: batch,
                                entity_type: "Contact", entity_id: contact.id, status: "pending")
    end
    bulk_action.update!(total_count: contacts.size, total_batches: 1, status: "processing")
    batch
  end

  it "applies the strategy to each pending row and marks them success" do
    bulk_action = create(:bulk_action, payload: { "status" => "active" })
    contacts = create_list(:contact, 3, account_id: bulk_action.account_id, status: "lead")
    batch = setup_batch(bulk_action: bulk_action, contacts: contacts)

    described_class.new.perform(batch.id)

    expect(contacts.map { |c| c.reload.status }).to all(eq("active"))
    expect(batch.reload.status).to eq("completed")

    bulk_action.reload
    expect(bulk_action.success_count).to eq(3)
    expect(bulk_action.completed_batches).to eq(1)
    expect(bulk_action.status).to eq("completed")
  end

  it "isolates a per-row validation failure without aborting the rest of the batch" do
    bulk_action = create(:bulk_action, payload: { "status" => "active" })
    good = create(:contact, account_id: bulk_action.account_id, status: "lead")
    bad = create(:contact, account_id: bulk_action.account_id, status: "lead")
    bad.update_column(:email, "") # bypasses validation to simulate a pre-existing bad row
    batch = setup_batch(bulk_action: bulk_action, contacts: [ good, bad ])

    described_class.new.perform(batch.id)

    expect(good.reload.status).to eq("active")
    expect(bad.reload.status).to eq("lead") # update! raised before persisting anything

    bulk_action.reload
    expect(bulk_action.success_count).to eq(1)
    expect(bulk_action.failed_count).to eq(1)
    expect(bulk_action.bulk_action_logs.failed.find_by(entity_id: bad.id).reason).to include("Email")
  end

  it "marks a row failed if its entity was deleted after planning" do
    bulk_action = create(:bulk_action, payload: { "status" => "active" })
    contact = create(:contact, account_id: bulk_action.account_id, status: "lead")
    batch = setup_batch(bulk_action: bulk_action, contacts: [ contact ])
    contact_id = contact.id
    contact.destroy

    described_class.new.perform(batch.id)

    bulk_action.reload
    expect(bulk_action.failed_count).to eq(1)
    expect(bulk_action.bulk_action_logs.failed.find_by(entity_id: contact_id).reason)
      .to eq("entity no longer exists")
  end

  it "is a no-op when redelivered after already completing" do
    bulk_action = create(:bulk_action, payload: { "status" => "active" })
    contact = create(:contact, account_id: bulk_action.account_id, status: "lead")
    batch = setup_batch(bulk_action: bulk_action, contacts: [ contact ])

    described_class.new.perform(batch.id)
    first_success_count = bulk_action.reload.success_count

    described_class.new.perform(batch.id)

    expect(bulk_action.reload.success_count).to eq(first_success_count)
  end

  it "no-ops if the parent bulk action has been cancelled" do
    bulk_action = create(:bulk_action, :cancelled, payload: { "status" => "active" })
    contact = create(:contact, account_id: bulk_action.account_id, status: "lead")
    batch = create(:bulk_action_batch, bulk_action: bulk_action, batch_number: 1)
    create(:bulk_action_log, bulk_action: bulk_action, bulk_action_batch: batch,
                              entity_type: "Contact", entity_id: contact.id, status: "pending")

    described_class.new.perform(batch.id)

    expect(contact.reload.status).to eq("lead")
    expect(batch.reload.status).to eq("pending")
  end

  it "requeues the batch via perform_in without processing rows when rate-limited" do
    bulk_action = create(:bulk_action, payload: { "status" => "active" })
    contact = create(:contact, account_id: bulk_action.account_id, status: "lead")
    batch = setup_batch(bulk_action: bulk_action, contacts: [ contact ])

    allow_any_instance_of(RateLimiter).to receive(:allow?).and_return(false)

    described_class.new.perform(batch.id)

    expect(contact.reload.status).to eq("lead")
    expect(batch.reload.status).to eq("processing") # claimed, but bounced back for capacity
    expect(described_class.jobs.size).to eq(1)
    expect(described_class.jobs.first["args"]).to eq([ batch.id ])
  end
end
