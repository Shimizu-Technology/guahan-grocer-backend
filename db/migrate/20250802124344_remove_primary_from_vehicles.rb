class RemovePrimaryFromVehicles < ActiveRecord::Migration[8.0]
  def up
    # Remove the index that includes is_primary
    remove_index :vehicles, [:user_id, :is_primary]
    
    # Clean up duplicate vehicles - keep only the oldest one per user
    execute <<-SQL
      DELETE FROM vehicles 
      WHERE id NOT IN (
        SELECT DISTINCT ON (user_id) id 
        FROM vehicles 
        ORDER BY user_id, created_at ASC
      );
    SQL
    
    # Remove the is_primary column
    remove_column :vehicles, :is_primary
    
    # Remove existing non-unique user_id index and add unique constraint
    remove_index :vehicles, :user_id
    add_index :vehicles, :user_id, unique: true
  end

  def down
    # Remove the unique constraint and add back non-unique index
    remove_index :vehicles, :user_id
    add_index :vehicles, :user_id
    
    # Add back the is_primary column
    add_column :vehicles, :is_primary, :boolean, default: false, null: false
    
    # Add back the composite index
    add_index :vehicles, [:user_id, :is_primary]
    
    # Set existing vehicles as primary
    execute <<-SQL
      UPDATE vehicles 
      SET is_primary = true 
      WHERE id IN (
        SELECT DISTINCT ON (user_id) id 
        FROM vehicles 
        ORDER BY user_id, created_at ASC
      );
    SQL
  end
end
