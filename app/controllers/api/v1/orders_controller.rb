class Api::V1::OrdersController < ApplicationController
  before_action :set_order, only: [:show, :update_status, :assign_driver]

  # GET /api/v1/orders
  def index
    @orders = orders_scope.includes(:user, :driver, :order_items, :products)
    render json: @orders.map { |order| order_json(order) }
  end

  # GET /api/v1/orders/:id
  def show
    ensure_order_access!(@order)
    render json: order_json(@order, include_items: true)
  end

  # POST /api/v1/orders
  def create
    ensure_customer!
    return if performed? # Stop if ensure_customer! rendered an error

    @order = current_user.orders.build(order_params)
    
    if @order.save
      # Create order items from cart data
      if params[:items].present?
        create_order_items(@order, params[:items])
      end
      
      render json: order_json(@order, include_items: true), status: :created
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/orders/:id/status
  def update_status
    ensure_order_management!(@order)
    return if performed? # Stop if ensure_order_management! rendered an error
    
    new_status = params[:status]
    
    if @order.update(status: new_status)
      render json: order_json(@order)
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/orders/:id/assign_driver
  def assign_driver
    ensure_admin!
    return if performed? # Stop if ensure_admin! rendered an error
    
    driver = User.driver.find(params[:driver_id])
    
    if @order.update(driver: driver)
      render json: order_json(@order)
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Driver not found'] }, status: :not_found
  end

  # GET /api/v1/orders/available
  def available
    ensure_driver!
    return if performed? # Stop if ensure_driver! rendered an error
    
    @orders = Order.where(driver: nil, status: 'pending').includes(:user, :order_items, :products)
    render json: @orders.map { |order| order_json(order) }
  end

  private

  def set_order
    @order = Order.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Order not found'] }, status: :not_found
  end

  def order_params
    params.require(:order).permit(:total, :eta, :estimated_payout, delivery_address: {})
  end

  def create_order_items(order, items_data)
    items_data.each do |item_data|
      product = Product.find(item_data[:itemId] || item_data[:item_id])
      order.order_items.create!(
        product: product,
        quantity: item_data[:quantity],
        price: item_data[:price] || product.price
      )
    end
  end

  def order_json(order, include_items: false)
    json = {
      id: order.id.to_s,
      userId: order.user_id.to_s,
      driverId: order.driver_id&.to_s,
      status: order.status,
      total: order.total.to_f,
      createdAt: order.created_at.iso8601,
      deliveryAddress: order.delivery_address,
      eta: order.eta,
      estimatedPayout: order.estimated_payout&.to_f
    }
    
    if include_items
      json[:items] = order.order_items.includes(:product, :substitute_product).map do |item|
        order_item_json(item)
      end
    end
    
    json
  end

  def order_item_json(order_item)
    {
      id: order_item.id.to_s,
      itemId: order_item.product_id.to_s,
      item: {
        id: order_item.product.id.to_s,
        name: order_item.product.name,
        price: order_item.product.price.to_f,
        unit: order_item.product.unit
      },
      quantity: order_item.quantity,
      price: order_item.price.to_f,
      status: order_item.status,
      foundQuantity: order_item.found_quantity,
      notes: order_item.notes,
      substituteItem: order_item.substitute_product&.id&.to_s
    }
  end
end 