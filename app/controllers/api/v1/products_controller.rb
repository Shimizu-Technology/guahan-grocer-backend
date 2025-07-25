class Api::V1::ProductsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_product, only: [:show, :update, :destroy]

  # GET /api/v1/products
  def index
    # For public access, use Product.all instead of policy_scope
    @products = current_user ? policy_scope(Product) : Product.all
    
    # Filter by category if provided
    @products = @products.where(category: params[:category]) if params[:category].present?
    
    # Filter by in_stock if provided
    @products = @products.where(in_stock: params[:in_stock]) if params[:in_stock].present?
    
    render json: @products.map { |product| product_json(product) }
  end

  # GET /api/v1/products/:id
  def show
    authorize @product if current_user
    render json: product_json(@product)
  end

  # POST /api/v1/products
  def create
    @product = Product.new(product_params)
    authorize @product
    
    if @product.save
      render json: product_json(@product), status: :created
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/products/:id
  def update
    authorize @product
    
    if @product.update(product_params)
      render json: product_json(@product)
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/products/:id
  def destroy
    authorize @product
    
    if @product.destroy
      render json: { message: 'Product deleted successfully' }
    else
      render json: { errors: ['Failed to delete product'] }, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Product not found'] }, status: :not_found
  end

  def product_params
    params.require(:product).permit(:name, :category, :price, :unit, :description, :in_stock, :stock_quantity, :image_key)
  end

  def product_json(product)
    {
      id: product.id.to_s,
      name: product.name,
      category: product.category,
      price: product.price.to_f,
      unit: product.unit,
      description: product.description,
      imageUrl: product.image_key ? generate_image_url(product.image_key) : nil,
      inStock: product.in_stock,
      stockQuantity: product.stock_quantity
    }
  end

  def generate_image_url(image_key)
    # For now, return a placeholder. Later we'll integrate with Imgix
    return nil if image_key.blank?
    "https://placeholder-image-url/#{image_key}"
  end
end 