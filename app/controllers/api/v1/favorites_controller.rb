class Api::V1::FavoritesController < ApplicationController
  # GET /api/v1/favorites
  def index
    @favorites = current_user.favorites.includes(:product)
    
    render json: @favorites.map { |favorite| favorite_json(favorite) }
  end

  # POST /api/v1/favorites
  def create
    product = Product.find(params[:product_id])
    @favorite = current_user.favorites.build(product: product)
    
    if @favorite.save
      render json: favorite_json(@favorite), status: :created
    else
      render json: { errors: @favorite.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Product not found'] }, status: :not_found
  end

  # DELETE /api/v1/favorites/:product_id
  def destroy
    @favorite = current_user.favorites.find_by(product_id: params[:product_id])
    
    if @favorite
      @favorite.destroy
      render json: { message: 'Removed from favorites' }
    else
      render json: { errors: ['Favorite not found'] }, status: :not_found
    end
  end

  private

  def favorite_json(favorite)
    product = favorite.product
    {
      id: favorite.id.to_s,
      userId: favorite.user_id.to_s,
      productId: favorite.product_id.to_s,
      product: {
        id: product.id.to_s,
        name: product.name,
        category: product.category,
        price: product.price.to_f,
        unit: product.unit,
        description: product.description,
        imageUrl: product.image_url,
        images: product.image_info,
        inStock: product.in_stock,
        stockQuantity: product.stock_quantity,
        hasImage: product.has_image?
      },
      createdAt: favorite.created_at.iso8601
    }
  end
end 