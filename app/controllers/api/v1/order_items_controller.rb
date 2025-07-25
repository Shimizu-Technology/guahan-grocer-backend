class Api::V1::OrderItemsController < ApplicationController
  before_action :set_order_item

  # PUT /api/v1/order_items/:id/status
  def update_status
    ensure_order_management!(@order_item.order)
    return if performed? # Stop if ensure_order_management! rendered an error
    
    new_status = params[:status]
    
    if @order_item.update(status: new_status)
      render json: order_item_json(@order_item)
    else
      render json: { errors: @order_item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/order_items/:id/found_quantity
  def update_found_quantity
    ensure_order_management!(@order_item.order)
    return if performed? # Stop if ensure_order_management! rendered an error
    
    found_quantity = params[:found_quantity].to_i
    notes = params[:notes]
    
    # Determine status based on found quantity
    new_status = if found_quantity == 0
                   'unavailable'
                 elsif found_quantity < @order_item.quantity
                   'found'  # Partial fulfillment
                 else
                   'found'  # Full fulfillment
                 end
    
    if @order_item.update(found_quantity: found_quantity, notes: notes, status: new_status)
      render json: order_item_json(@order_item)
    else
      render json: { errors: @order_item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/order_items/:id/substitute
  def substitute
    ensure_order_management!(@order_item.order)
    return if performed? # Stop if ensure_order_management! rendered an error
    
    substitute_product = Product.find(params[:substitute_product_id])
    notes = params[:notes] || "Substituted with #{substitute_product.name}"
    
    if @order_item.update(
      substitute_product: substitute_product,
      status: 'substituted',
      notes: notes,
      found_quantity: params[:found_quantity] || @order_item.quantity
    )
      render json: order_item_json(@order_item)
    else
      render json: { errors: @order_item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Substitute product not found'] }, status: :not_found
  end

  private

  def set_order_item
    @order_item = OrderItem.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Order item not found'] }, status: :not_found
  end

  def order_item_json(order_item)
    {
      id: order_item.id.to_s,
      orderId: order_item.order_id.to_s,
      itemId: order_item.product_id.to_s,
      item: {
        id: order_item.product.id.to_s,
        name: order_item.product.name,
        price: order_item.product.price.to_f,
        unit: order_item.product.unit,
        category: order_item.product.category
      },
      quantity: order_item.quantity,
      price: order_item.price.to_f,
      status: order_item.status,
      foundQuantity: order_item.found_quantity,
      notes: order_item.notes,
      substituteProduct: order_item.substitute_product ? {
        id: order_item.substitute_product.id.to_s,
        name: order_item.substitute_product.name,
        price: order_item.substitute_product.price.to_f,
        unit: order_item.substitute_product.unit
      } : nil
    }
  end
end 