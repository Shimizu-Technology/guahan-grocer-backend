class AddPaymentFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :estimated_total, :decimal, precision: 10, scale: 2
    add_column :orders, :pre_auth_amount, :decimal, precision: 10, scale: 2
    add_column :orders, :final_total, :decimal, precision: 10, scale: 2
    add_column :orders, :payment_intent_id, :string
    add_column :orders, :payment_status, :string, default: 'pending', null: false
    add_column :orders, :payment_method, :string, default: 'mock', null: false
    add_column :orders, :variance_summary, :jsonb
    
    # Add indexes for efficient querying
    add_index :orders, :payment_status
    add_index :orders, :payment_intent_id, unique: true
  end
end
