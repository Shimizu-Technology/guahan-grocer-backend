class EnhanceDriverStats < ActiveRecord::Migration[8.0]
  def change
    add_column :driver_stats, :tips, :decimal, precision: 8, scale: 2, default: 0.0
    add_column :driver_stats, :base_pay, :decimal, precision: 8, scale: 2, default: 0.0
    add_column :driver_stats, :bonuses, :decimal, precision: 8, scale: 2, default: 0.0
    add_column :driver_stats, :expenses, :decimal, precision: 8, scale: 2, default: 0.0
    add_column :driver_stats, :hours_online, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :driver_stats, :orders_offered, :integer, default: 0
    add_column :driver_stats, :orders_accepted, :integer, default: 0
    add_column :driver_stats, :went_online_at, :datetime
    add_column :driver_stats, :went_offline_at, :datetime
  end
end
