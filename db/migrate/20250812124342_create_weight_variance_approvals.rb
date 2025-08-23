class CreateWeightVarianceApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :weight_variance_approvals do |t|
      t.references :order_item, null: false, foreign_key: true
      t.decimal :original_weight, precision: 8, scale: 3
      t.decimal :new_weight, precision: 8, scale: 3
      t.decimal :original_price, precision: 10, scale: 2
      t.decimal :new_price, precision: 10, scale: 2
      t.decimal :variance_percentage, precision: 5, scale: 2
      t.string :approval_status, null: false, limit: 50, default: 'pending'
      t.string :approval_method, limit: 50
      t.timestamp :customer_response_at
      t.timestamp :timeout_at
      t.text :driver_note

      t.timestamps
    end
    
    # Add indexes for efficient querying
    add_index :weight_variance_approvals, :approval_status
    add_index :weight_variance_approvals, :timeout_at
    add_index :weight_variance_approvals, [:order_item_id, :approval_status]
  end
end
