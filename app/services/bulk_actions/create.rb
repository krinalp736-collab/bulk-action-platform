module BulkActions
  # The only place that decides queued-vs-scheduled and kicks off the first
  # job — keeps BulkActionsController a thin param-passer.
  class Create
    def self.call(attributes)
      new(attributes).call
    end

    def initialize(attributes)
      @attributes = attributes
    end

    def call
      bulk_action = BulkAction.new(attributes)
      bulk_action.status = bulk_action.scheduled_at.present? ? :scheduled : :queued
      schedule!(bulk_action) if bulk_action.save
      bulk_action
    end

    private

    attr_reader :attributes

    def schedule!(bulk_action)
      if bulk_action.scheduled_at.present?
        BulkActionEnqueueJob.perform_at(bulk_action.scheduled_at, bulk_action.id)
      else
        BulkActionEnqueueJob.perform_async(bulk_action.id)
      end
    end
  end
end
