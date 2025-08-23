class ApplicationController < ActionController::API
  before_action :authenticate_user!

  private

  def authenticate_user!
    header = request.headers['Authorization']
    header = header.split(' ').last if header

    begin
      @decoded = JWT.decode(header, Rails.application.secret_key_base)[0]
      @current_user = User.find(@decoded['user_id'])
    rescue JWT::DecodeError => e
      render json: { errors: ['Invalid token'] }, status: :unauthorized
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: ['User not found'] }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  # Simple authorization helpers - no complex autoloading
  def ensure_admin!
    unless current_user&.admin?
      render json: { errors: ['Admin access required'] }, status: :forbidden
    end
  end

  def ensure_driver!
    unless current_user&.driver?
      render json: { errors: ['Driver access required'] }, status: :forbidden
    end
  end

  def ensure_customer!
    unless current_user&.customer?
      render json: { errors: ['Customer access required'] }, status: :forbidden
    end
  end

  def ensure_admin_or_self!(user_record)
    unless current_user&.admin? || current_user == user_record
      render json: { errors: ['Not authorized to access this resource'] }, status: :forbidden
    end
  end

  def ensure_order_access!(order)
    # Allow access if:
    # - User is admin
    # - User is the customer who placed the order
    # - User is the assigned driver
    # - User is a driver and order is pending with no driver assigned (available for acceptance)
    
    allowed = current_user&.admin? || 
              order.user == current_user || 
              order.driver == current_user ||
              (current_user&.driver? && order.driver_id.nil? && order.status == 'pending')
    
    unless allowed
      render json: { errors: ['Not authorized to access this order'] }, status: :forbidden
    end
  end

  def ensure_order_management!(order)
    unless current_user&.admin? || order.driver == current_user
      render json: { errors: ['Not authorized to manage this order'] }, status: :forbidden
    end
  end

  def ensure_customer_access!(order)
    # Ensure the current user is the customer who placed the order or an admin
    unless current_user&.admin? || order.user == current_user
      render json: { errors: ['Not authorized to access this order'] }, status: :forbidden
    end
  end

  # Scope methods that work reliably without autoloading
  def orders_scope
    return Order.all if current_user.admin?
    
    if current_user.driver?
      # Check if driver has any active orders (not completed or cancelled)
      active_orders = Order.where(driver: current_user, status: ['accepted', 'shopping', 'delivering'])
      
      if active_orders.exists?
        # Driver has active orders - only show those, no available orders
        return active_orders
      else
        # Driver has no active orders - show their completed orders + available orders
        return Order.where(driver: current_user).or(Order.where(driver: nil, status: 'pending'))
      end
    end
    
    return Order.where(user: current_user) if current_user.customer?
    Order.none
  end

  def users_scope
    return User.all if current_user.admin?
    User.where(id: current_user.id)
  end

  # Allow certain actions to skip authentication
  def skip_authentication
    # This can be called from specific controllers for public endpoints
  end
end
