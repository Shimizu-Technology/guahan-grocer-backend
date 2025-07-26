class Api::V1::ProductsController < ApplicationController
  before_action :set_product, only: [:show, :update, :destroy, :upload_image, :delete_image]
  
  # Skip authentication for public product viewing
  skip_before_action :authenticate_user!, only: [:index, :show]

  # GET /api/v1/products
  def index
    @products = Product.all
    
    # Apply filters
    @products = @products.by_category(params[:category]) if params[:category].present?
    @products = @products.in_stock if params[:in_stock] == 'true'
    @products = @products.low_stock if params[:low_stock] == 'true'
    
    # Include image URLs for all products
    render json: @products.map { |product| product_json(product) }
  end

  # GET /api/v1/products/:id
  def show
    render json: product_json(@product, detailed: true)
  end

  # POST /api/v1/products (Admin only)
  def create
    ensure_admin!
    return if performed?

    @product = Product.new(product_params)
    
    if @product.save
      # Handle image upload if provided
      if params[:image].present?
        begin
          upload_result = @product.upload_image(params[:image])
          Rails.logger.info "Image uploaded for product #{@product.id}: #{upload_result[:s3_key]}"
        rescue S3Uploader::UploadError => e
          Rails.logger.error "Image upload failed for product #{@product.id}: #{e.message}"
          # Continue without image - don't fail the product creation
        end
      end
      
      render json: product_json(@product, detailed: true), status: :created
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/products/:id (Admin only)
  def update
    ensure_admin!
    return if performed?

    if @product.update(product_params)
      render json: product_json(@product, detailed: true)
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/products/:id (Admin only)
  def destroy
    ensure_admin!
    return if performed?

    # Delete associated image from S3
    @product.delete_image if @product.has_image?
    
    @product.destroy
    head :no_content
  end

  # POST /api/v1/products/:id/image (Admin only)
  def upload_image
    ensure_admin!
    return if performed?

    unless params[:image].present?
      render json: { errors: ['No image file provided'] }, status: :bad_request
      return
    end

    begin
      upload_result = @product.upload_image(params[:image])
      
      render json: {
        message: 'Image uploaded successfully',
        product: product_json(@product, detailed: true),
        image: {
          s3_key: upload_result[:s3_key],
          public_url: upload_result[:public_url],
          imgix_url: upload_result[:imgix_url]
        }
      }
    rescue S3Uploader::UploadError => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    rescue S3Uploader::ConfigurationError => e
      render json: { errors: ['Image upload service not configured'] }, status: :internal_server_error
    end
  end

  # DELETE /api/v1/products/:id/image (Admin only)
  def delete_image
    ensure_admin!
    return if performed?

    unless @product.has_image?
      render json: { errors: ['Product has no image to delete'] }, status: :bad_request
      return
    end

    if @product.delete_image
      render json: {
        message: 'Image deleted successfully',
        product: product_json(@product, detailed: true)
      }
    else
      render json: { errors: ['Failed to delete image'] }, status: :internal_server_error
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Product not found'] }, status: :not_found
  end

  def product_params
    params.require(:product).permit(:name, :category, :price, :unit, :description, :in_stock, :stock_quantity)
  end

  def product_json(product, detailed: false)
    json = {
      id: product.id.to_s,
      name: product.name,
      category: product.category,
      price: product.price.to_f,
      unit: product.unit,
      inStock: product.in_stock?,
      stockQuantity: product.stock_quantity
    }

    # Add image information
    if product.has_image?
      json[:imageUrl] = product.image_url
      json[:images] = product.image_info
    else
      json[:imageUrl] = nil
      json[:images] = nil
    end

    if detailed
      json.merge!({
        description: product.description,
        createdAt: product.created_at.iso8601,
        updatedAt: product.updated_at.iso8601,
        lowStock: product.low_stock?,
        outOfStock: product.out_of_stock?,
        hasImage: product.has_image?
      })
    end

    json
  end
end 