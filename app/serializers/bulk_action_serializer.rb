class BulkActionSerializer
  def initialize(bulk_action)
    @bulk_action = bulk_action
  end

  def as_json(*)
    {
      id: bulk_action.id,
      account_id: bulk_action.account_id,
      entity_type: bulk_action.entity_type,
      action_type: bulk_action.action_type,
      status: bulk_action.status,
      filter: bulk_action.filter,
      contact_ids: bulk_action.contact_ids,
      payload: bulk_action.payload,
      scheduled_at: bulk_action.scheduled_at,
      total_count: bulk_action.total_count,
      success_count: bulk_action.success_count,
      failed_count: bulk_action.failed_count,
      skipped_count: bulk_action.skipped_count,
      processed_count: bulk_action.processed_count,
      percentage_complete: bulk_action.percentage_complete,
      total_batches: bulk_action.total_batches,
      completed_batches: bulk_action.completed_batches,
      error_message: bulk_action.error_message,
      started_at: bulk_action.started_at,
      completed_at: bulk_action.completed_at,
      created_at: bulk_action.created_at,
      updated_at: bulk_action.updated_at
    }
  end

  private

  attr_reader :bulk_action
end
