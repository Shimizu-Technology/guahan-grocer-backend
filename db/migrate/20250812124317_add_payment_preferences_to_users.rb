class AddPaymentPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :auto_approve_variances, :boolean, default: false, null: false
    add_column :users, :max_auto_variance_percentage, :integer, default: 15, null: false
    add_column :users, :auto_approve_overages_only, :boolean, default: false, null: false
    add_column :users, :variance_notification_method, :string, default: 'push', null: false, limit: 50
    add_column :users, :approval_timeout_minutes, :integer, default: 10, null: false
    
    # Add indexes for efficient querying
    add_index :users, :auto_approve_variances
  end
end
