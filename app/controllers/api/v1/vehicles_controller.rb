class Api::V1::VehiclesController < ApplicationController
  before_action :ensure_driver_or_admin
  before_action :set_vehicle, only: [:show, :update, :destroy]
  before_action :ensure_vehicle_ownership, only: [:show, :update, :destroy]

  # GET /api/v1/vehicles
  def index
    vehicle = vehicles_scope
    if vehicle
      render json: vehicle_json(vehicle)
    else
      render json: null
    end
  end

  # GET /api/v1/vehicles/:id
  def show
    render json: vehicle_json(@vehicle, detailed: true)
  end

  # POST /api/v1/vehicles
  def create
    if current_user.vehicle.present?
      render json: { errors: ['Driver already has a vehicle registered'] }, status: :unprocessable_entity
      return
    end

    @vehicle = current_user.build_vehicle(vehicle_params)
    
    if @vehicle.save
      render json: vehicle_json(@vehicle, detailed: true), status: :created
    else
      render json: { errors: @vehicle.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/vehicles/:id
  def update
    if @vehicle.update(vehicle_update_params)
      render json: vehicle_json(@vehicle, detailed: true)
    else
      render json: { errors: @vehicle.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/vehicles/:id
  def destroy
    @vehicle.destroy
    render json: { message: 'Vehicle deleted successfully' }
  end

  private

  def ensure_driver_or_admin
    unless current_user.driver? || current_user.admin?
      render json: { errors: ['Only drivers can manage vehicles'] }, status: :forbidden
    end
  end

  def set_vehicle
    @vehicle = Vehicle.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Vehicle not found'] }, status: :not_found
  end

  def ensure_vehicle_ownership
    if current_user.admin?
      # Admins can manage any vehicle
      return
    elsif @vehicle.user != current_user
      render json: { errors: ['You can only manage your own vehicles'] }, status: :forbidden
    end
  end

  def vehicles_scope
    if current_user.admin? && params[:driver_id].present?
      # Admins can view vehicle for specific driver
      User.find(params[:driver_id]).vehicle
    else
      # Drivers can only see their own vehicle
      current_user.vehicle
    end
  end

  def vehicle_params
    params.require(:vehicle).permit(
      :make, :model, :year, :color, :license_plate, :vehicle_type
    )
  end

  def vehicle_update_params
    # Verification status can only be updated by admins
    if current_user.admin?
      vehicle_params.merge(params.require(:vehicle).permit(:verification_status))
    else
      vehicle_params
    end
  end

  def vehicle_json(vehicle, detailed: false)
    json = {
      id: vehicle.id.to_s,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      color: vehicle.color,
      licensePlate: vehicle.license_plate,
      vehicleType: vehicle.vehicle_type,
      verificationStatus: vehicle.verification_status,
      displayName: vehicle.display_name,
      fullDescription: vehicle.full_description,
      needsVerification: vehicle.needs_verification?,
      canBeUsedForDelivery: vehicle.can_be_used_for_delivery?
    }

    if detailed
      json.merge!({
        userId: vehicle.user_id.to_s,
        createdAt: vehicle.created_at.iso8601,
        updatedAt: vehicle.updated_at.iso8601
      })
    end

    json
  end
end
