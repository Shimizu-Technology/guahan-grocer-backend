class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :register]

  # POST /api/v1/auth/login
  def login
    # Normalize email for case-insensitive lookup
    normalized_email = params[:email].downcase.strip if params[:email].present?
    user = User.find_by(email: normalized_email)
    
    if user&.authenticate(params[:password])
      if user.active?
        token = generate_token(user)
        render json: {
          token: token,
          user: user_json(user)
        }, status: :ok
      else
        render json: { errors: ['Account is inactive'] }, status: :forbidden
      end
    else
      render json: { errors: ['Invalid email or password'] }, status: :unauthorized
    end
  end

  # POST /api/v1/auth/register
  def register
    user = User.new(user_params)
    user.role = 'customer' # Default role for registration
    
    # Normalize email for case-insensitive handling
    user.email = user.email.downcase.strip if user.email.present?
    
    if user.save
      token = generate_token(user)
      render json: {
        token: token,
        user: user_json(user)
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/auth/me
  def me
    render json: { user: user_json(current_user) }, status: :ok
  end

  # DELETE /api/v1/auth/logout
  def logout
    # For JWT, logout is typically handled client-side by removing the token
    # We could implement token blacklisting here if needed
    render json: { message: 'Logged out successfully' }, status: :ok
  end

  # DELETE /api/v1/auth/delete_account
  def delete_account
    user = current_user
    
    # Check if user has any active orders
    if user.orders.where(status: ['pending', 'confirmed', 'in_progress', 'out_for_delivery']).exists?
      render json: { 
        errors: ['Cannot delete account with active orders. Please wait for all orders to be completed or cancelled.'] 
      }, status: :unprocessable_entity
      return
    end
    
    # For drivers, check if they have any active assignments
    if user.driver? && user.driver_orders.where(status: ['confirmed', 'in_progress', 'out_for_delivery']).exists?
      render json: { 
        errors: ['Cannot delete account with active delivery assignments. Please complete all deliveries first.'] 
      }, status: :unprocessable_entity
      return
    end
    
    # Soft delete by deactivating the account and anonymizing data
    begin
      User.transaction do
        # Anonymize user data for privacy compliance
        user.update!(
          name: "Deleted User #{user.id}",
          email: "deleted_#{user.id}@deleted.local",
          phone: "000-000-0000",
          active: false,
          password: SecureRandom.hex(32) # Reset password to random value
        )
        
        # Clear any personal data in related records
        user.addresses.destroy_all
        user.favorites.destroy_all
        
        # Orders are preserved with anonymized user data for business analytics
        # The orders still reference the user_id but user is now anonymized
      end
      
      render json: { message: 'Account deleted successfully' }, status: :ok
    rescue => e
      render json: { errors: ['Failed to delete account. Please try again.'] }, status: :internal_server_error
    end
  end



  # PUT /api/v1/auth/toggle_online
  def toggle_online
    unless current_user.driver?
      render json: { errors: ['Only drivers can toggle online status'] }, status: :forbidden
      return
    end

    if current_user.online?
      success = current_user.go_offline!
      message = 'You are now offline'
    else
      success = current_user.go_online!
      message = 'You are now online'
    end

    if success
      render json: { 
        message: message, 
        user: user_json(current_user) 
      }, status: :ok
    else
      render json: { errors: ['Failed to toggle online status'] }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :phone)
  end

  def generate_token(user)
    payload = {
      user_id: user.id,
      role: user.role,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base)
  end

  def user_json(user)
    {
      id: user.id.to_s,
      email: user.email,
      name: user.name,
      role: user.role,
      phone: user.phone,
      isOnline: user.is_online,
      createdAt: user.created_at.iso8601
    }
  end
end 