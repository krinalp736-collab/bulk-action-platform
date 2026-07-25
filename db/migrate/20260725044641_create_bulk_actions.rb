class CreateBulkActions < ActiveRecord::Migration[8.1]
  def change
    create_table :bulk_actions do |t|
      t.string :account_id, null: false
      t.string :entity_type, null: false
      t.string :action_type, null: false
      t.integer :status, null: false, default: 0

      # `filter`/`contact_ids` describe WHICH entities to target (mutually exclusive
      # from the client's point of view); `payload` is the generic, strategy-specific
      # instruction (field updates for bulk_update, nothing for bulk_archive, etc.)
      # so adding a new action never requires a schema change here.
      t.jsonb :filter, null: false, default: {}
      t.jsonb :contact_ids
      t.jsonb :payload, null: false, default: {}

      t.datetime :scheduled_at
      # Freezes the target set at submission time so the run can't silently grow
      # if rows are inserted after the bulk action is created.
      t.bigint :snapshot_max_id

      t.integer :total_count, null: false, default: 0
      t.integer :success_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :total_batches, null: false, default: 0
      t.integer :completed_batches, null: false, default: 0

      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :bulk_actions, :account_id
    add_index :bulk_actions, :status
    add_index :bulk_actions, [ :account_id, :status ]
    add_index :bulk_actions, :scheduled_at
  end
end
