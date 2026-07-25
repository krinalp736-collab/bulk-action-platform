module BulkActions
  # The single place new bulk actions get wired in. Adding "Bulk Delete" or
  # "Bulk Email" later means adding one class + one line here — nothing else
  # in the system (controllers, jobs, models) needs to change.
  class Registry
    UnknownActionError = Class.new(StandardError)

    MAPPING = {
      %w[Contact bulk_update] => "BulkActions::ContactBulkUpdate",
      %w[Contact bulk_archive] => "BulkActions::ContactBulkArchive"
    }.freeze

    class << self
      def resolve(entity_type, action_type)
        class_name = MAPPING[key_for(entity_type, action_type)]
        raise UnknownActionError, "no bulk action registered for #{entity_type}/#{action_type}" unless class_name

        class_name.constantize
      end

      def registered?(entity_type, action_type)
        MAPPING.key?(key_for(entity_type, action_type))
      end

      def entity_class_for(entity_type)
        entity_type.to_s.constantize
      end

      private

      def key_for(entity_type, action_type)
        [ entity_type.to_s, action_type.to_s ]
      end
    end
  end
end
