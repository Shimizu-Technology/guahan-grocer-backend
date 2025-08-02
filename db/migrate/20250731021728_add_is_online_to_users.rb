class AddIsOnlineToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_online, :boolean, default: false, null: false
    add_index :users, [:role, :is_online], name: 'index_users_on_role_and_is_online'
  end
end
