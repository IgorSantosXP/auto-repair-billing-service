class CreateBudgetItems < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_items do |t|
      t.references :budget, null: false, foreign_key: true
      t.string  :kind, null: false
      t.string  :reference_id
      t.string  :name, null: false
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false
      t.integer :total_cents, null: false

      t.timestamps
    end

    add_check_constraint :budget_items, "kind IN ('service','part')", name: "budget_items_kind_check"
    add_check_constraint :budget_items, "quantity > 0", name: "budget_items_quantity_check"
  end
end
