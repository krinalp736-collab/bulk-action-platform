module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ContactsFilterQuery::InvalidFilterError, with: :render_unprocessable
      rescue_from BulkActions::Registry::UnknownActionError, with: :render_unprocessable
      rescue_from ActionController::ParameterMissing, with: :render_unprocessable

      private

      def render_not_found(error)
        render json: { error: error.message }, status: :not_found
      end

      def render_unprocessable(error)
        render json: { error: error.message }, status: :unprocessable_content
      end
    end
  end
end
