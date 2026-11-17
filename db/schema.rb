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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_120400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "budget_items", force: :cascade do |t|
    t.bigint "budget_id", null: false
    t.string "kind", null: false
    t.string "reference_id"
    t.string "name", null: false
    t.integer "quantity", null: false
    t.integer "unit_price_cents", null: false
    t.integer "total_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id"], name: "index_budget_items_on_budget_id"
    t.check_constraint "kind::text = ANY (ARRAY['service'::character varying, 'part'::character varying]::text[])", name: "budget_items_kind_check"
    t.check_constraint "quantity > 0", name: "budget_items_quantity_check"
  end

  create_table "budgets", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.uuid "service_order_uuid", null: false
    t.string "saga_id"
    t.string "customer_id", null: false
    t.string "customer_name"
    t.string "customer_email"
    t.string "customer_document"
    t.jsonb "vehicle", default: {}, null: false
    t.string "status", default: "pending_approval", null: false
    t.integer "total_cents", default: 0, null: false
    t.string "approval_token_digest"
    t.datetime "approval_token_expires_at"
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_budgets_on_customer_id"
    t.index ["service_order_uuid"], name: "index_budgets_on_service_order_uuid", unique: true
    t.index ["status"], name: "index_budgets_on_status"
    t.index ["uuid"], name: "index_budgets_on_uuid", unique: true
    t.check_constraint "status::text = ANY (ARRAY['pending_approval'::character varying, 'approved'::character varying, 'rejected'::character varying, 'paid'::character varying, 'cancelled'::character varying, 'refunded'::character varying]::text[])", name: "budgets_status_check"
    t.check_constraint "total_cents >= 0", name: "budgets_total_cents_check"
  end

  create_table "outbox_messages", force: :cascade do |t|
    t.string "message_id", null: false
    t.string "message_type", null: false
    t.string "destination", null: false
    t.jsonb "body", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_outbox_messages_on_pending", where: "(published_at IS NULL)"
    t.index ["message_id"], name: "index_outbox_messages_on_message_id", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "budget_id", null: false
    t.string "provider", default: "mercadopago", null: false
    t.string "mode", default: "fake", null: false
    t.string "preference_id"
    t.string "provider_payment_id"
    t.string "status", default: "pending", null: false
    t.integer "amount_cents", null: false
    t.string "payment_url"
    t.string "refund_id"
    t.string "failure_reason"
    t.jsonb "raw", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id"], name: "index_payments_on_budget_id"
    t.index ["provider_payment_id"], name: "index_payments_on_provider_payment_id", unique: true, where: "(provider_payment_id IS NOT NULL)"
    t.check_constraint "mode::text = ANY (ARRAY['fake'::character varying, 'live'::character varying]::text[])", name: "payments_mode_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'refunded'::character varying, 'refund_failed'::character varying]::text[])", name: "payments_status_check"
  end

  create_table "processed_messages", force: :cascade do |t|
    t.string "message_id", null: false
    t.datetime "created_at", null: false
    t.index ["message_id"], name: "index_processed_messages_on_message_id", unique: true
  end

  add_foreign_key "budget_items", "budgets"
  add_foreign_key "payments", "budgets"
end
