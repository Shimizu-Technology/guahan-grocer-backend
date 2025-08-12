class CreateOrderEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :order_events do |t|
      t.references :order, null: false, foreign_key: true
      t.string :event_type, null: false
      t.references :user, null: true, foreign_key: true  # Some events might be system-generated
      t.jsonb :data, default: {}
      t.datetime :occurred_at, null: false
      t.text :description  # Human-readable description of the event

      t.timestamps
    end

    # Add indexes for common queries
    add_index :order_events, [:order_id, :occurred_at]
    add_index :order_events, [:event_type, :occurred_at]
    add_index :order_events, [:user_id, :occurred_at], where: "user_id IS NOT NULL"
  end
end
