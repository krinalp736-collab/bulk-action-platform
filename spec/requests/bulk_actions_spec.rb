require "rails_helper"

RSpec.describe "Bulk Actions API", type: :request do
  describe "POST /bulk-actions" do
    it "creates a bulk action and enqueues the planning job" do
      post "/bulk-actions", as: :json, params: {
        bulk_action: {
          account_id: "acc_test", entity_type: "Contact", action_type: "bulk_update",
          filter: { status: "lead" }, payload: { status: "active" }
        }
      }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["status"]).to eq("queued")
      expect(BulkActionEnqueueJob.jobs.size).to eq(1)
    end

    it "returns 422 with error messages for invalid attributes" do
      post "/bulk-actions", as: :json, params: {
        bulk_action: { account_id: "acc_test", entity_type: "Contact", action_type: "nope" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "runs the full pipeline synchronously end-to-end under Sidekiq inline testing" do
      create_list(:contact, 3, account_id: "acc_test", status: "lead")

      Sidekiq::Testing.inline! do
        post "/bulk-actions", as: :json, params: {
          bulk_action: { account_id: "acc_test", entity_type: "Contact", action_type: "bulk_update",
                         filter: { status: "lead" }, payload: { status: "active" } }
        }
      end

      bulk_action = BulkAction.find(response.parsed_body["id"])
      expect(bulk_action.status).to eq("completed")
      expect(bulk_action.success_count).to eq(3)
    end
  end

  describe "GET /bulk-actions" do
    it "lists bulk actions, filterable by account_id and status" do
      mine = create(:bulk_action, account_id: "acc_a", status: "completed")
      create(:bulk_action, account_id: "acc_b")

      get "/bulk-actions", params: { account_id: "acc_a" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |ba| ba["id"] }).to contain_exactly(mine.id)
    end
  end

  describe "GET /bulk-actions/:id" do
    it "returns the bulk action" do
      bulk_action = create(:bulk_action)

      get "/bulk-actions/#{bulk_action.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(bulk_action.id)
    end

    it "404s for an unknown id" do
      get "/bulk-actions/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /bulk-actions/:id/stats" do
    it "returns the counters and percentage complete" do
      bulk_action = create(:bulk_action, total_count: 10, success_count: 4, failed_count: 1, skipped_count: 1)

      get "/bulk-actions/#{bulk_action.id}/stats"

      body = response.parsed_body
      expect(body["processed_count"]).to eq(6)
      expect(body["percentage_complete"]).to eq(60.0)
    end
  end

  describe "GET /bulk-actions/:id/logs" do
    it "filters by status and returns a keyset pagination cursor" do
      bulk_action = create(:bulk_action)
      failed = create(:bulk_action_log, bulk_action: bulk_action, status: "failed")
      create(:bulk_action_log, bulk_action: bulk_action, status: "success")

      get "/bulk-actions/#{bulk_action.id}/logs", params: { status: "failed" }

      body = response.parsed_body
      expect(body["logs"].map { |l| l["id"] }).to eq([ failed.id ])
      expect(body["next_cursor"]).to eq(failed.id)
    end
  end

  describe "PATCH /bulk-actions/:id/cancel" do
    it "cancels a cancellable bulk action" do
      bulk_action = create(:bulk_action, status: "queued")

      patch "/bulk-actions/#{bulk_action.id}/cancel"

      expect(response).to have_http_status(:ok)
      expect(bulk_action.reload.status).to eq("cancelled")
    end

    it "422s for a bulk action that can't be cancelled" do
      bulk_action = create(:bulk_action, :completed)

      patch "/bulk-actions/#{bulk_action.id}/cancel"

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
