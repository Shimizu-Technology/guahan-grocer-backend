class ChangeVehicleTypeToInteger < ActiveRecord::Migration[8.0]
  def up
    # Convert existing string values to integers before changing column type
    execute <<-SQL
      UPDATE vehicles 
      SET vehicle_type = CASE 
        WHEN vehicle_type = 'sedan' THEN '0'
        WHEN vehicle_type = 'suv' THEN '1'
        WHEN vehicle_type = 'truck' THEN '2'
        WHEN vehicle_type = 'hatchback' THEN '3'
        WHEN vehicle_type = 'coupe' THEN '4'
        WHEN vehicle_type = 'convertible' THEN '5'
        WHEN vehicle_type = 'van' THEN '6'
        WHEN vehicle_type = 'minivan' THEN '7'
        WHEN vehicle_type = 'pickup' THEN '8'
        WHEN vehicle_type = 'other' THEN '9'
        ELSE '0'
      END
      WHERE vehicle_type IS NOT NULL;
    SQL
    
    # Change column type to integer with default using explicit casting
    execute "ALTER TABLE vehicles ALTER COLUMN vehicle_type TYPE integer USING vehicle_type::integer;"
    change_column_default :vehicles, :vehicle_type, 0
    change_column_null :vehicles, :vehicle_type, false
  end

  def down
    # Change back to string
    change_column :vehicles, :vehicle_type, :string, null: false
    
    # Convert integer values back to strings
    execute <<-SQL
      UPDATE vehicles 
      SET vehicle_type = CASE 
        WHEN vehicle_type = '0' THEN 'sedan'
        WHEN vehicle_type = '1' THEN 'suv'
        WHEN vehicle_type = '2' THEN 'truck'
        WHEN vehicle_type = '3' THEN 'hatchback'
        WHEN vehicle_type = '4' THEN 'coupe'
        WHEN vehicle_type = '5' THEN 'convertible'
        WHEN vehicle_type = '6' THEN 'van'
        WHEN vehicle_type = '7' THEN 'minivan'
        WHEN vehicle_type = '8' THEN 'pickup'
        WHEN vehicle_type = '9' THEN 'other'
        ELSE 'sedan'
      END;
    SQL
  end
end
