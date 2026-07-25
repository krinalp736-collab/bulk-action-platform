class CreateBulkActionBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :bulk_action_batches do |t|
      t.references :bulk_action, null: false, foreign_key: true
      t.integer :batch_number, null: false
      t.integer :status, null: false, default: 0
      t.integer :retry_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    # One row per (bulk_action, batch_number): the claim/finalize guards in
    # BulkActionBatchJob rely on this being unique to make completion detection
    # exactly-once even under Sidekiq's at-least-once redelivery.
    add_index :bulk_action_batches, [ :bulk_action_id, :batch_number ], unique: true
    add_index :bulk_action_batches, [ :bulk_action_id, :status ]
  end
end
