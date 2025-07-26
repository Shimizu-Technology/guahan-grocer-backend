class Api::V1::AdminController < ApplicationController
  before_action :ensure_admin!

  # GET /api/v1/admin/dashboard
  def dashboard
    stats = calculate_dashboard_stats
    recent_activity = get_recent_activity
    
    render json: {
      stats: stats,
      recent_activity: recent_activity
    }
  end

  private

  def calculate_dashboard_stats
    # Calculate today's date range
    today = Date.current
    today_start = today.beginning_of_day
    today_end = today.end_of_day

    {
      total_orders: Order.count,
      total_customers: User.customer.count,
      active_drivers: User.driver.where(active: true).count,
      revenue_today: Order.where(created_at: today_start..today_end)
                         .where(status: ['delivered'])
                         .sum(:total)
                         .to_f
                         .round(2),
      revenue_total: Order.where(status: ['delivered'])
                         .sum(:total)
                         .to_f
                         .round(2),
      orders_today: Order.where(created_at: today_start..today_end).count,
      pending_orders: Order.where(status: 'pending').count,
      low_stock_products: Product.where('stock_quantity <= ?', 10).count
    }
  end

  def get_recent_activity
    activities = []

    # Recent orders (last 10)
    recent_orders = Order.includes(:user)
                        .order(created_at: :desc)
                        .limit(5)
    
    recent_orders.each do |order|
      activities << {
        type: 'order',
        message: "New order ##{order.id} from #{order.user.name}",
        time: time_ago_in_words(order.created_at),
        timestamp: order.created_at
      }
    end

    # Recent user registrations (last 5)
    recent_users = User.customer
                      .order(created_at: :desc)
                      .limit(3)
    
    recent_users.each do |user|
      activities << {
        type: 'customer',
        message: "New customer #{user.name} registered",
        time: time_ago_in_words(user.created_at),
        timestamp: user.created_at
      }
    end

    # Low stock alerts
    low_stock = Product.where('stock_quantity <= ?', 10)
                      .where(in_stock: true)
                      .limit(3)
    
    low_stock.each do |product|
      activities << {
        type: 'inventory',
        message: "Low stock alert: #{product.name} (#{product.stock_quantity} left)",
        time: 'Now',
        timestamp: Time.current
      }
    end

    # Sort by timestamp and return most recent
    activities.sort_by { |a| a[:timestamp] }
             .reverse
             .first(8)
             .map { |a| a.except(:timestamp) }
  end

  def time_ago_in_words(time)
    seconds = Time.current - time
    
    case seconds
    when 0..59
      "#{seconds.to_i} seconds ago"
    when 60..3599
      "#{(seconds / 60).to_i} minutes ago"
    when 3600..86399
      "#{(seconds / 3600).to_i} hours ago"
    else
      "#{(seconds / 86400).to_i} days ago"
    end
  end
end 