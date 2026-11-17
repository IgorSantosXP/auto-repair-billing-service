class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets do |t|
      t.uuid   :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.uuid   :service_order_uuid, null: false
      t.string :saga_id
      t.string :customer_id, null: false
      t.string :customer_name
      t.string :customer_email
      t.string :customer_document
      t.jsonb  :vehicle, null: false, default: {}
      t.string :status, null: false, default: "pending_approval"
      t.integer :total_cents, null: false, default: 0
      t.string   :approval_token_digest
      t.datetime :approval_token_expires_at
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :budgets, :uuid, unique: true
    add_index :budgets, :service_order_uuid, unique: true
    add_index :budgets, :customer_id
    add_index :budgets, :status
    add_check_constraint :budgets,
                         "status IN ('pending_approval','approved','rejected','paid','cancelled','refunded')",
                         name: "budgets_status_check"
    add_check_constraint :budgets, "total_cents >= 0", name: "budgets_total_cents_check"
  end
end
