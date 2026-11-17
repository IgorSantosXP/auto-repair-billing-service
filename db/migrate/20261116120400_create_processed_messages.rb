class CreateProcessedMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_messages do |t|
      t.string   :message_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :processed_messages, :message_id, unique: true
  end
end
