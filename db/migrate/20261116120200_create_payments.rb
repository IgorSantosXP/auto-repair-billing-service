class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :budget, null: false, foreign_key: true
      t.string  :provider, null: false, default: "mercadopago"
      t.string  :mode, null: false, default: "fake"
      t.string  :preference_id
      t.string  :provider_payment_id
      t.string  :status, null: false, default: "pending"
      t.integer :amount_cents, null: false
      t.string  :payment_url
      t.string  :refund_id
      t.string  :failure_reason
      t.jsonb   :raw, null: false, default: {}

      t.timestamps
    end

    add_index :payments, :provider_payment_id, unique: true, where: "provider_payment_id IS NOT NULL"
    add_check_constraint :payments, "mode IN ('fake','live')", name: "payments_mode_check"
    add_check_constraint :payments,
                         "status IN ('pending','approved','rejected','refunded','refund_failed')",
                         name: "payments_status_check"
  end
end
