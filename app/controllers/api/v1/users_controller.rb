class Api::V1::UsersController < ApplicationController
  before_action :set_user, only: [:show, :update]

  # GET /api/v1/users
  def index
    ensure_admin!
    return if performed? # Stop if ensure_admin! rendered an error
    
    @users = users_scope
    
    # Filter by role if provided
    @users = @users.where(role: params[:role]) if params[:role].present?
    
    # Filter by status if provided
    @users = @users.where(active: params[:active]) if params[:active].present?
    
    render json: @users.map { |user| user_json(user) }
  end

  # GET /api/v1/users/:id
  def show
    ensure_admin_or_self!(@user)
    return if performed? # Stop if ensure_admin_or_self! rendered an error
    
    render json: user_json(@user, detailed: true)
  end

  # PUT /api/v1/users/:id
  def update
    ensure_admin_or_self!(@user)
    return if performed? # Stop if ensure_admin_or_self! rendered an error
    
    if @user.update(user_update_params)
      render json: user_json(@user, detailed: true)
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/drivers/available
  def available_drivers
    ensure_admin!
    return if performed? # Stop if ensure_admin! rendered an error
    
    # Find available drivers (those who are active and not currently assigned)
    @drivers = User.driver.where(active: true)
    
    render json: @drivers.map { |driver| driver_json(driver) }
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['User not found'] }, status: :not_found
  end

  def user_update_params
    # Admins can update more fields than regular users
    if current_user.admin?
      params.require(:user).permit(:name, :email, :phone, :role, :active)
    else
      params.require(:user).permit(:name, :email, :phone)
    end
  end

  def user_json(user, detailed: false)
    json = {
      id: user.id.to_s,
      name: user.name,
      email: user.email,
      role: user.role,
      active: user.active
    }
    
    if detailed
      json.merge!({
        phone: user.phone,
        createdAt: user.created_at.iso8601,
        updatedAt: user.updated_at.iso8601
      })
      
      # Add role-specific details
      if user.driver?
        json[:driverStats] = latest_driver_stats(user)
      end
    end
    
    json
  end

  def driver_json(driver)
    {
      id: driver.id.to_s,
      name: driver.name,
      email: driver.email,
      phone: driver.phone,
      active: driver.active,
      stats: latest_driver_stats(driver)
    }
  end

  def latest_driver_stats(driver)
    latest_stat = driver.driver_stats.order(date: :desc).first
    return nil unless latest_stat
    
    {
      totalDeliveries: latest_stat.total_deliveries,
      totalEarnings: latest_stat.total_earnings.to_f,
      averageRating: latest_stat.average_rating&.to_f,
      totalRatings: latest_stat.total_ratings
    }
  end
end 