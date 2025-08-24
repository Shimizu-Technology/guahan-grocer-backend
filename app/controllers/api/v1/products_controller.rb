class Api::V1::ProductsController < ApplicationController
  before_action :set_product, only: [:show, :update, :destroy, :upload_image, :delete_image, :weight_info]
  
  # Skip authentication for public product viewing
  skip_before_action :authenticate_user!, only: [:index, :show, :featured]

  # GET /api/v1/products
  def index
    @products = Product.all
    
    # Apply filters
    @products = @products.by_category(params[:category]) if params[:category].present?
    @products = @products.available if params[:available] == 'true'
    @products = @products.in_stock if params[:in_stock] == 'true'  # Keep for backward compatibility
    @products = @products.low_stock if params[:low_stock] == 'true'
    
    # Include image URLs for all products
    render json: @products.map { |product| product_json(product) }
  end

  # GET /api/v1/products/featured
  def featured
    @products = Product.where(featured: true).available
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

    # Extract image from params before creating product
    image_file = product_params[:image]
    product_attributes = product_params.except(:category_ids, :image)
    
    @product = Product.new(product_attributes)
    
    if @product.save
      # Handle category associations
      if params[:product][:category_ids].present?
        @product.category_ids = params[:product][:category_ids]
      end
      
      # Handle image upload if provided
      image_upload_error = nil
      if image_file.present?
        begin
          upload_result = @product.upload_image(image_file)
          Rails.logger.info "Image uploaded for product #{@product.id}: #{upload_result[:s3_key]}"
        rescue S3Uploader::ConfigurationError => e
          Rails.logger.warn "S3 not configured for product #{@product.id}: #{e.message}"
          # For development: save a placeholder image URL
          @product.update(image_url: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300')
          Rails.logger.info "Using fallback image URL for development"
        rescue S3Uploader::UploadError => e
          Rails.logger.error "Image upload failed for product #{@product.id}: #{e.message}"
          image_upload_error = e.message
          # Continue without image - don't fail the product creation
        end
      end
      
      response = product_json(@product, detailed: true)
      response[:imageUploadError] = image_upload_error if image_upload_error
      render json: response, status: :created
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

  # GET /api/v1/products/:id/weight_info
  def weight_info
    unless @product.weight_based?
      render json: { error: 'Product is not weight-based' }, status: :bad_request
      return
    end

    render json: {
      id: @product.id.to_s,
      name: @product.name,
      weightBased: @product.weight_based?,
      pricePerUnit: @product.price_per_unit.to_f,
      weightUnit: @product.weight_unit,
      minWeight: @product.min_weight&.to_f,
      maxWeight: @product.max_weight&.to_f,
      weightRange: @product.weight_range_text,
      priceInfo: @product.display_price_info,
      sampleCalculations: {
        "0.5" => @product.calculate_price_for_weight(0.5),
        "1.0" => @product.calculate_price_for_weight(1.0),
        "1.5" => @product.calculate_price_for_weight(1.5),
        "2.0" => @product.calculate_price_for_weight(2.0)
      }
    }
  end

  private

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Product not found'] }, status: :not_found
  end

  def product_params
    params.require(:product).permit(:name, :price, :unit_id, :description, :in_stock, :stock_quantity, :featured, :track_inventory, :image, :weight_based, :price_per_unit, :weight_unit, :min_weight, :max_weight, category_ids: [])
  end

  def product_json(product, detailed: false)
    json = {
      id: product.id.to_s,
      name: product.name,
      categories: product.categories.map { |cat| { id: cat.id, name: cat.name } },
      category: product.categories.first&.name, # For backward compatibility
      price: product.price.to_f,
      unit: product.unit.name,
      unitId: product.unit_id,
      unitSymbol: product.unit.symbol,
      inStock: product.in_stock?,
      stockQuantity: product.display_stock_quantity,
      featured: product.featured,
      trackInventory: product.track_inventory,
      stockStatus: product.display_stock_status,
      available: product.available?,
      weightBased: product.weight_based?,
      weightUnit: product.weight_based? ? product.weight_unit : nil,
      pricePerUnit: product.weight_based? ? product.price_per_unit.to_f : nil
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
      detailed_info = {
        description: product.description,
        createdAt: product.created_at.iso8601,
        updatedAt: product.updated_at.iso8601,
        lowStock: product.low_stock?,
        outOfStock: product.out_of_stock?,
        hasImage: product.has_image?,
        actualStockQuantity: product.track_inventory? ? product.stock_quantity : nil
      }
      
      # Add weight-based details
      if product.weight_based?
        detailed_info.merge!({
          minWeight: product.min_weight&.to_f,
          maxWeight: product.max_weight&.to_f,
          weightRange: product.weight_range_text,
          priceInfo: product.display_price_info
        })
      end
      
      json.merge!(detailed_info)
    end

    json
  end
end 