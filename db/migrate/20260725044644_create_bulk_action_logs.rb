class CreateBulkActionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :bulk_action_logs do |t|
      t.references :bulk_action, null: false, foreign_key: true
      # Null for rows resolved at planning time (duplicate-email skips) which
      # never get assigned to a batch at all.
      t.references :bulk_action_batch, null: true, foreign_key: true
      t.string :entity_type, null: false
      t.bigint :entity_id, null: false
      t.integer :status, null: false, default: 0
      t.text :reason
      t.datetime :processed_at

      t.datetime :created_at, null: false
    end

    # Idempotency guard: a given entity can only have one log row per bulk
    # action, so retried/re-entrant work can never double-log the same entity.
    add_index :bulk_action_logs, [ :bulk_action_id, :entity_id ], unique: true
    add_index :bulk_action_logs, [ :bulk_action_id, :status ]
    add_index :bulk_action_logs, [ :bulk_action_batch_id, :status ]
  end
end
