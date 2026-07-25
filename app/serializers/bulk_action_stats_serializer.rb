class BulkActionStatsSerializer
  def initialize(bulk_action)
    @bulk_action = bulk_action
  end

  def as_json(*)
    {
      id: bulk_action.id,
      status: bulk_action.status,
      total_count: bulk_action.total_count,
      success_count: bulk_action.success_count,
      failed_count: bulk_action.failed_count,
      skipped_count: bulk_action.skipped_count,
      processed_count: bulk_action.processed_count,
      percentage_complete: bulk_action.percentage_complete,
      total_batches: bulk_action.total_batches,
      completed_batches: bulk_action.completed_batches
    }
  end

  private

  attr_reader :bulk_action
end
