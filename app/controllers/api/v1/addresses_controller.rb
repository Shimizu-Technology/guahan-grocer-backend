class Api::V1::AddressesController < ApplicationController
  before_action :set_address, only: [:show, :update, :destroy, :make_default]

  # GET /api/v1/addresses
  def index
    @addresses = current_user.addresses.default_first
    render json: @addresses.map { |address| address_json(address) }
  end

  # GET /api/v1/addresses/:id
  def show
    render json: address_json(@address)
  end

  # POST /api/v1/addresses
  def create
    @address = current_user.addresses.build(address_params)
    
    # If this is the user's first address, make it default
    @address.is_default = true if current_user.addresses.empty?
    
    if @address.save
      render json: address_json(@address), status: :created
    else
      render json: { errors: @address.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/addresses/:id
  def update
    if @address.update(address_params)
      render json: address_json(@address)
    else
      render json: { errors: @address.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/addresses/:id
  def destroy
    was_default = @address.is_default?
    
    if @address.destroy
      # If we deleted the default address, make the most recent one default
      if was_default && current_user.addresses.exists?
        current_user.addresses.order(created_at: :desc).first.make_default!
      end
      
      render json: { message: 'Address deleted successfully' }
    else
      render json: { errors: @address.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/addresses/:id/make_default
  def make_default
    @address.make_default!
    render json: address_json(@address)
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def set_address
    @address = current_user.addresses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Address not found'] }, status: :not_found
  end

  def address_params
    params.require(:address).permit(:label, :street_address, :apartment_unit, :city, :state, :zip_code, :is_default, :latitude, :longitude)
  end

  def address_json(address)
    {
      id: address.id.to_s,
      label: address.label,
      displayLabel: address.display_label,
      streetAddress: address.street_address,
      apartmentUnit: address.apartment_unit,
      city: address.city,
      state: address.state,
      zipCode: address.zip_code,
      isDefault: address.is_default,
      fullAddress: address.full_address,
      latitude: address.latitude,
      longitude: address.longitude,
      createdAt: address.created_at.iso8601,
      updatedAt: address.updated_at.iso8601
    }
  end
end
