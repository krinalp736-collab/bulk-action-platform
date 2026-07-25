class BulkActionLogSerializer
  def initialize(log)
    @log = log
  end

  def as_json(*)
    {
      id: log.id,
      entity_type: log.entity_type,
      entity_id: log.entity_id,
      status: log.status,
      reason: log.reason,
      processed_at: log.processed_at,
      created_at: log.created_at
    }
  end

  private

  attr_reader :log
end
