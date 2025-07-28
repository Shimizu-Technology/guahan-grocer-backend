class Api::V1::StoresController < ApplicationController
  before_action :set_store, only: [:show, :update, :destroy]
  before_action :ensure_admin!, except: [:index, :show]

  # GET /api/v1/stores
  def index
    @stores = Store.all.order(:name)
    render json: @stores.map { |store| store_json(store) }
  end

  # GET /api/v1/stores/:id
  def show
    render json: store_json(@store)
  end

  # POST /api/v1/stores
  def create
    @store = Store.new(store_params)
    
    if @store.save
      render json: store_json(@store), status: :created
    else
      render json: { errors: @store.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/stores/:id
  def update
    if @store.update(store_params)
      render json: store_json(@store)
    else
      render json: { errors: @store.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/stores/:id
  def destroy
    if @store.destroy
      render json: { message: 'Store deleted successfully' }
    else
      render json: { errors: @store.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/stores/:id/toggle_active
  def toggle_active
    ensure_admin!
    return if performed?
    
    @store = Store.find(params[:id])
    
    if @store.update(active: !@store.active)
      render json: store_json(@store)
    else
      render json: { errors: @store.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Store not found'] }, status: :not_found
  end

  private

  def set_store
    @store = Store.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Store not found'] }, status: :not_found
  end

  def store_params
    params.require(:store).permit(:name, :address, :phone, :latitude, :longitude, :active)
  end

  def store_json(store)
    {
      id: store.id.to_s,
      name: store.name,
      address: store.address,
      phone: store.phone,
      latitude: store.latitude.to_f,
      longitude: store.longitude.to_f,
      active: store.active,
      coordinates: store.coordinates,
      displayName: store.display_name,
      createdAt: store.created_at.iso8601,
      updatedAt: store.updated_at.iso8601
    }
  end
end
