class Api::V1::CategoriesController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  before_action :set_category, only: [:show, :update, :destroy]
  before_action :admin_required, only: [:create, :update, :destroy]

  def index
    @categories = Category.active.by_name
    render json: @categories.map { |category| category_json(category) }
  end

  def create
    @category = Category.new(category_params)
    
    if @category.save
      render json: category_json(@category), status: :created
    else
      render json: { error: @category.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def show
    render json: category_json(@category)
  end

  def update
    if @category.update(category_params)
      render json: category_json(@category)
    else
      render json: { error: @category.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.products.any?
      render json: { error: 'Cannot delete category with associated products' }, status: :unprocessable_entity
    else
      @category.destroy
      render json: { message: 'Category deleted successfully' }
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Category not found' }, status: :not_found
  end

  def category_params
    params.require(:category).permit(:name, :description, :active, :icon, :color)
  end

  def category_json(category)
    {
      id: category.id,
      name: category.name,
      description: category.description,
      icon: category.icon,
      color: category.color,
      active: category.active,
      products_count: category.products.count,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end

  def admin_required
    unless current_user&.admin?
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end
end
