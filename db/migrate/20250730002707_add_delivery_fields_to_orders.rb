class AddDeliveryFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :delivery_instructions, :text
    add_column :orders, :delivery_time, :string
  end
end
