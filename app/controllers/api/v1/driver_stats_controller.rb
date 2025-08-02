class Api::V1::DriverStatsController < ApplicationController
  before_action :ensure_driver_or_admin

  # GET /api/v1/driver_stats
  def index
    @stats = driver_stats_scope.order(:date)
    
    # Filter by date range if provided
    if params[:start_date].present?
      @stats = @stats.where('date >= ?', Date.parse(params[:start_date]))
    end
    
    if params[:end_date].present?
      @stats = @stats.where('date <= ?', Date.parse(params[:end_date]))
    end
    
    # Default to last 30 days if no range provided
    if params[:start_date].blank? && params[:end_date].blank?
      @stats = @stats.where('date >= ?', 30.days.ago)
    end
    
    render json: @stats.map { |stat| driver_stat_json(stat) }
  end

  # GET /api/v1/driver_stats/:date
  def show
    date = Date.parse(params[:date])
    @stat = driver_stats_scope.find_by(date: date)
    
    if @stat
      render json: driver_stat_json(@stat, detailed: true)
    else
      # Return empty stats for the date
      render json: empty_stat_json(date)
    end
  rescue Date::Error
    render json: { errors: ['Invalid date format'] }, status: :bad_request
  end

  private

  def ensure_driver_or_admin
    unless current_user.driver? || current_user.admin?
      render json: { errors: ['Only drivers can access driver stats'] }, status: :forbidden
    end
  end

  def driver_stats_scope
    if current_user.admin? && params[:driver_id].present?
      # Admins can view specific driver stats
      User.find(params[:driver_id]).driver_stats
    else
      # Drivers can only see their own stats
      current_user.driver_stats
    end
  end

  def driver_stat_json(stat, detailed: false)
    json = {
      id: stat.id.to_s,
      userId: stat.user_id.to_s,
      date: stat.date.iso8601,
      totalDeliveries: stat.total_deliveries,
      totalEarnings: stat.total_earnings.to_f,
      averageRating: stat.average_rating&.to_f,
      totalRatings: stat.total_ratings,
      # Detailed earnings breakdown
      tips: stat.tips.to_f,
      basePay: stat.base_pay.to_f,
      bonuses: stat.bonuses.to_f,
      expenses: stat.expenses.to_f,
      hoursOnline: stat.hours_online.to_f,
      ordersOffered: stat.orders_offered,
      ordersAccepted: stat.orders_accepted,
      # Calculated metrics
      acceptanceRate: stat.acceptance_rate,
      ordersPerHour: stat.orders_per_hour,
      hourlyRate: stat.hourly_rate,
      netEarnings: stat.net_earnings.to_f
    }
    
    if detailed
      json.merge!({
        averageEarningsPerDelivery: stat.total_deliveries > 0 ? (stat.total_earnings / stat.total_deliveries).to_f : 0.0,
        createdAt: stat.created_at.iso8601,
        updatedAt: stat.updated_at.iso8601
      })
    end
    
    json
  end

  def empty_stat_json(date)
    {
      date: date.iso8601,
      totalDeliveries: 0,
      totalEarnings: 0.0,
      averageRating: nil,
      totalRatings: 0,
      tips: 0.0,
      basePay: 0.0,
      bonuses: 0.0,
      expenses: 0.0,
      hoursOnline: 0.0,
      ordersOffered: 0,
      ordersAccepted: 0,
      acceptanceRate: 0,
      ordersPerHour: 0.0,
      hourlyRate: 0.0,
      netEarnings: 0.0,
      averageEarningsPerDelivery: 0.0
    }
  end
end 