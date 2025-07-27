class Api::V1::UnitsController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  before_action :set_unit, only: [:show, :update, :destroy]
  before_action :admin_required, only: [:create, :update, :destroy]

  def index
    @units = Unit.active.by_name
    render json: @units.map { |unit| unit_json(unit) }
  end

  def create
    @unit = Unit.new(unit_params)
    
    if @unit.save
      render json: unit_json(@unit), status: :created
    else
      render json: { error: @unit.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def show
    render json: unit_json(@unit)
  end

  def update
    if @unit.update(unit_params)
      render json: unit_json(@unit)
    else
      render json: { error: @unit.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    if @unit.can_be_deleted?
      @unit.destroy
      render json: { message: 'Unit deleted successfully' }
    else
      render json: { error: 'Cannot delete unit with associated products' }, status: :unprocessable_entity
    end
  end

  private

  def set_unit
    @unit = Unit.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unit not found' }, status: :not_found
  end

  def unit_params
    params.require(:unit).permit(:name, :symbol, :active)
  end

  def unit_json(unit)
    {
      id: unit.id,
      name: unit.name,
      symbol: unit.symbol,
      displayName: unit.display_name,
      active: unit.active,
      products_count: unit.products.count,
      created_at: unit.created_at,
      updated_at: unit.updated_at
    }
  end

  def admin_required
    unless current_user&.admin?
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end
end
