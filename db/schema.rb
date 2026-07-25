# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_25_044644) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bulk_action_batches", force: :cascade do |t|
    t.integer "batch_number", null: false
    t.bigint "bulk_action_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "retry_count", default: 0, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["bulk_action_id", "batch_number"], name: "index_bulk_action_batches_on_bulk_action_id_and_batch_number", unique: true
    t.index ["bulk_action_id", "status"], name: "index_bulk_action_batches_on_bulk_action_id_and_status"
    t.index ["bulk_action_id"], name: "index_bulk_action_batches_on_bulk_action_id"
  end

  create_table "bulk_action_logs", force: :cascade do |t|
    t.bigint "bulk_action_batch_id"
    t.bigint "bulk_action_id", null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "entity_type", null: false
    t.datetime "processed_at"
    t.text "reason"
    t.integer "status", default: 0, null: false
    t.index ["bulk_action_batch_id", "status"], name: "index_bulk_action_logs_on_bulk_action_batch_id_and_status"
    t.index ["bulk_action_batch_id"], name: "index_bulk_action_logs_on_bulk_action_batch_id"
    t.index ["bulk_action_id", "entity_id"], name: "index_bulk_action_logs_on_bulk_action_id_and_entity_id", unique: true
    t.index ["bulk_action_id", "status"], name: "index_bulk_action_logs_on_bulk_action_id_and_status"
    t.index ["bulk_action_id"], name: "index_bulk_action_logs_on_bulk_action_id"
  end

  create_table "bulk_actions", force: :cascade do |t|
    t.string "account_id", null: false
    t.string "action_type", null: false
    t.datetime "completed_at"
    t.integer "completed_batches", default: 0, null: false
    t.jsonb "contact_ids"
    t.datetime "created_at", null: false
    t.string "entity_type", null: false
    t.text "error_message"
    t.integer "failed_count", default: 0, null: false
    t.jsonb "filter", default: {}, null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "scheduled_at"
    t.integer "skipped_count", default: 0, null: false
    t.bigint "snapshot_max_id"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "success_count", default: 0, null: false
    t.integer "total_batches", default: 0, null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_bulk_actions_on_account_id_and_status"
    t.index ["account_id"], name: "index_bulk_actions_on_account_id"
    t.index ["scheduled_at"], name: "index_bulk_actions_on_scheduled_at"
    t.index ["status"], name: "index_bulk_actions_on_status"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "account_id", null: false
    t.integer "age"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "status", default: "lead", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email"
    t.index ["account_id", "status"], name: "index_contacts_on_account_id_and_status"
    t.index ["account_id"], name: "index_contacts_on_account_id"
    t.index ["email"], name: "index_contacts_on_email"
  end

  add_foreign_key "bulk_action_batches", "bulk_actions"
  add_foreign_key "bulk_action_logs", "bulk_action_batches"
  add_foreign_key "bulk_action_logs", "bulk_actions"
end
