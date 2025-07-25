class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :register]

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email])
    
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
      role: user.role
    }
  end
end 