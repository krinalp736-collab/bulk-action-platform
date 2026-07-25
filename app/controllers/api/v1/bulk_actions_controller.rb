module Api
  module V1
    class BulkActionsController < BaseController
      before_action :set_bulk_action, only: %i[show stats logs cancel]

      # GET /bulk-actions
      def index
        scope = BulkAction.order(id: :desc)
        scope = scope.for_account(params[:account_id]) if params[:account_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?

        bulk_actions = scope.limit(bounded_limit(default: 50, max: 200)).offset(params[:offset].to_i)
        render json: bulk_actions.map { |ba| BulkActionSerializer.new(ba).as_json }
      end

      # POST /bulk-actions
      def create
        bulk_action = BulkActions::Create.call(bulk_action_params)

        if bulk_action.persisted?
          render json: BulkActionSerializer.new(bulk_action).as_json, status: :created
        else
          render json: { errors: bulk_action.errors.full_messages }, status: :unprocessable_content
        end
      end

      # GET /bulk-actions/:id
      def show
        render json: BulkActionSerializer.new(@bulk_action).as_json
      end

      # GET /bulk-actions/:id/stats
      def stats
        render json: BulkActionStatsSerializer.new(@bulk_action).as_json
      end

      # GET /bulk-actions/:id/logs?status=failed&after=:cursor&limit=100
      def logs
        logs = @bulk_action.bulk_action_logs
                            .with_status(params[:status])
                            .after(params[:after])
                            .ordered
                            .limit(bounded_limit(default: 100, max: 1000))

        render json: {
          logs: logs.map { |l| BulkActionLogSerializer.new(l).as_json },
          next_cursor: logs.last&.id
        }
      end

      # PATCH /bulk-actions/:id/cancel
      def cancel
        if @bulk_action.cancel!
          render json: BulkActionSerializer.new(@bulk_action).as_json
        else
          render json: { error: "can't cancel a bulk action with status=#{@bulk_action.status}" },
                 status: :unprocessable_content
        end
      end

      private

      def set_bulk_action
        @bulk_action = BulkAction.find(params[:id])
      end

      def bulk_action_params
        params.require(:bulk_action).permit(
          :account_id, :entity_type, :action_type, :scheduled_at,
          filter: {}, payload: {}, contact_ids: []
        ).to_h
      end

      def bounded_limit(default:, max:)
        params.fetch(:limit, default).to_i.clamp(1, max)
      end
    end
  end
end
