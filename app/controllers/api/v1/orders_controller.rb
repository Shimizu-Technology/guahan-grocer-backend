class Api::V1::OrdersController < ApplicationController
  before_action :set_order, only: [:show, :update_status, :assign_driver, :accept_order]

  # GET /api/v1/orders
  def index
    @orders = orders_scope.includes(:user, :driver, :order_items, :products)
    render json: @orders.map { |order| order_json(order, include_items: true) }
  end

  # GET /api/v1/orders/:id
  def show
    ensure_order_access!(@order)
    return if performed? # Stop if ensure_order_access! rendered an error
    
    # Include driver-specific data if user is a driver
    is_driver_request = current_user&.driver? && (@order.driver == current_user || @order.driver_id.nil?)
    render json: order_json(@order, include_items: true, for_driver: is_driver_request)
  end

  # POST /api/v1/orders
  def create
    ensure_customer!
    return if performed? # Stop if ensure_customer! rendered an error

    @order = current_user.orders.build(order_params)
    
    # Fast-path: Use fallback delivery details to avoid blocking API calls
    ensure_fast_delivery_details(@order)
    
    if @order.save
      # Create order items from cart data using bulk insert
      if params[:items].present?
        create_order_items_bulk(@order, params[:items])
      end
      
      # Queue background job to calculate accurate delivery details
      CalculateDeliveryDetailsJob.perform_later(@order.id) if @order.delivery_address.present?
      
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
    old_status = @order.status
    
    if @order.update(status: new_status)
      # Update driver stats when order is delivered
      if new_status == 'delivered' && old_status != 'delivered' && @order.driver.present?
        update_driver_stats_for_delivery(@order)
      end
      
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
    
    # Assign driver and move to accepted if currently pending
    new_status = @order.status == 'pending' ? 'accepted' : @order.status
    if @order.update(driver: driver, status: new_status)
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
    
    # Only show orders to online drivers
    unless current_user.online?
      render json: { 
        errors: ['You must be online to view available orders'], 
        message: 'Go online to see available orders' 
      }, status: :forbidden
      return
    end
    
    # Use orders_scope to implement smart driver logic:
    # - If driver has active orders, show only those
    # - If driver has no active orders, show available + completed orders
    @orders = orders_scope.includes(:user, :order_items, :products)
    render json: @orders.map { |order| order_json(order, include_items: true, for_driver: true) }
  end

  # GET /api/v1/orders/active (for drivers)
  def active
    ensure_driver!
    return if performed? # Stop if ensure_driver! rendered an error
    
    @order = current_user.orders.where(status: ['accepted', 'shopping', 'delivering']).includes(:order_items, :products).first
    
    if @order
      render json: order_json(@order, include_items: true, for_driver: true)
    else
      render json: { active_order: nil }
    end
  end

  # PUT /api/v1/orders/:id/accept (for drivers)
  def accept_order
    ensure_driver!
    return if performed? # Stop if ensure_driver! rendered an error

    # Only allow online drivers to accept orders
    unless current_user.online?
      render json: { 
        errors: ['You must be online to accept orders'], 
        message: 'Go online to accept orders' 
      }, status: :forbidden
      return
    end

    # Check if order is available
    unless @order.driver.nil? && @order.status == 'pending'
      render json: { errors: ['This order is no longer available'] }, status: :unprocessable_entity
      return
    end

    # Assign driver and update status
    if @order.update(driver: current_user, status: 'accepted')
      render json: { 
        message: 'Order accepted successfully', 
        order: order_json(@order, include_items: true, for_driver: true) 
      }, status: :ok
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/orders/calculate_delivery_fee
  def calculate_delivery_fee
    delivery_address = params[:delivery_address]
    
    unless delivery_address.present?
      render json: { errors: ['Delivery address is required'] }, status: :bad_request
      return
    end

    # Fast check if Google Maps API is available
    unless ENV['GOOGLE_MAPS_API_KEY'].present?
      Rails.logger.warn "Google Maps API key not configured, using fallback delivery fee"
      render json: {
        delivery_fee: 6.99,
        closest_store: Store.where(active: true).first&.name || 'Store',
        distance_details: nil,
        address_error: {
          message: 'Distance calculation not available',
          suggestion: 'Using standard delivery fee'
        }
      }
      return
    end

    begin
      # Format address string
      address_string = format_delivery_address(delivery_address)
      
      # Apply address correction if needed
      correction_result = DistanceCalculator.get_corrected_address(address_string)
      final_address = correction_result[:corrected_address]
      
      # Calculate delivery details with timeout
      delivery_result = Timeout::timeout(10) do
        DistanceCalculator.calculate_delivery_with_details(final_address)
      end
      
      # Prepare response data
      response_data = {
        delivery_fee: delivery_result[:delivery_fee],
        closest_store: delivery_result[:closest_store]&.name,
        distance_details: delivery_result[:distance_details]
      }
      
      # Handle address not found error
      unless delivery_result[:success]
        response_data[:address_error] = {
          message: delivery_result[:error],
          suggestion: "Please check your address and try again, or try using just the village name (e.g., 'Yona, GU 96914')"
        }
      end
      
      # Add address correction notice if correction was applied
      if correction_result[:correction_applied]
        response_data[:address_correction] = {
          original_address: correction_result[:original_address],
          corrected_address: correction_result[:corrected_address],
          reason: correction_result[:reason],
          message: "We've automatically corrected your address for accurate delivery calculation."
        }
      end
      
      render json: response_data
    rescue Timeout::Error
      Rails.logger.warn "Delivery fee calculation timed out"
      render json: {
        delivery_fee: 6.99,
        closest_store: Store.where(active: true).first&.name || 'Store',
        distance_details: nil,
        address_error: {
          message: 'Distance calculation timed out',
          suggestion: 'Using standard delivery fee. Please try again.'
        }
      }
    rescue => e
      Rails.logger.error "Delivery fee calculation failed: #{e.message}"
      render json: {
        delivery_fee: 6.99,
        closest_store: Store.where(active: true).first&.name || 'Store',
        distance_details: nil,
        address_error: {
          message: 'Distance calculation failed',
          suggestion: 'Using standard delivery fee'
        }
      }
    end
  end

  # POST /api/v1/orders/:id/receipt
  def upload_receipt
    set_order
    ensure_order_management!(@order)
    return if performed? # Stop if ensure_order_management! rendered an error

    unless params[:receipt].present?
      render json: { errors: ['No receipt image provided'] }, status: :bad_request
      return
    end

    # Ensure order is in the right state for receipt upload
    unless %w[shopping delivering].include?(@order.status)
      render json: { errors: ['Receipt can only be uploaded during shopping or delivery'] }, status: :unprocessable_entity
      return
    end

    begin
      # Generate receipt-specific S3 path
      timestamp = Time.current.to_i
      extension = File.extname(params[:receipt].original_filename)
      s3_key = "receipts/order_#{@order.id}/#{timestamp}#{extension}"
      
      # Upload to S3 using the generic upload method
      upload_result = S3Uploader.upload(params[:receipt], s3_key)
      
      # Store receipt information in the order
      @order.update!(
        receipt_url: upload_result[:s3_key],
        receipt_uploaded_at: Time.current
      )
      
      render json: {
        message: 'Receipt uploaded successfully',
        order: order_json(@order),
        receipt: {
          s3_key: upload_result[:s3_key],
          public_url: upload_result[:public_url],
          uploaded_at: @order.receipt_uploaded_at.iso8601
        }
      }
    rescue S3Uploader::UploadError => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    rescue S3Uploader::ConfigurationError => e
      render json: { errors: ['Receipt upload service not configured'] }, status: :internal_server_error
    rescue => e
      Rails.logger.error "Receipt upload failed for order #{@order.id}: #{e.message}"
      render json: { errors: ['Failed to upload receipt'] }, status: :internal_server_error
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Order not found'] }, status: :not_found
  end

  def order_params
    params.require(:order).permit(:total, :subtotal, :delivery_fee, :actual_delivery_fee, :eta, :estimated_payout, :tip_amount, :tip_percentage, :delivery_instructions, :delivery_time, :assigned_store_id, :store_distance_miles, :store_name, :estimated_delivery_minutes, delivery_address: {})
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

  # Optimized bulk creation of order items
  def create_order_items_bulk(order, items_data)
    # Pre-load all products to avoid N+1 queries
    product_ids = items_data.map { |item| item[:itemId] || item[:item_id] }
    products = Product.where(id: product_ids).index_by(&:id)
    
    # Prepare bulk insert data
    order_items_attributes = items_data.map do |item_data|
      product_id = (item_data[:itemId] || item_data[:item_id]).to_i
      product = products[product_id]
      
      raise ActiveRecord::RecordNotFound, "Product not found: #{product_id}" unless product
      
      {
        order_id: order.id,
        product_id: product_id,
        quantity: item_data[:quantity],
        price: item_data[:price] || product.price,
        status: 0, # pending
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    # Bulk insert all order items
    OrderItem.insert_all(order_items_attributes)
  end

  def order_json(order, include_items: false, for_driver: false)
    json = {
      id: order.id.to_s,
      userId: order.user_id.to_s,
      driverId: order.driver_id&.to_s,
      status: order.status,
      total: order.total.to_f,
      createdAt: order.created_at.iso8601,
      deliveryAddress: order.delivery_address,
      eta: order.eta,
      estimatedPayout: order.estimated_payout&.to_f || 0.0,
      tipAmount: order.tip_amount.to_f,
      tipPercentage: order.tip_percentage.to_f,
      deliveryInstructions: order.delivery_instructions,
      deliveryTime: order.delivery_time,
      subtotal: order.subtotal.to_f,
      deliveryFee: order.delivery_fee.to_f,
      actualDeliveryFee: order.actual_delivery_fee&.to_f,
      assigned: order.driver_id.present?
    }
    
    if include_items
      json[:items] = order.order_items.includes(:product, :substitute_product).map do |item|
        order_item_json(item)
      end
    end
    
    # Add driver and vehicle information
    # - For admins: always include if a driver is present (needed for assignment workflows)
    # - For customers/drivers: include only when order is in a visible state
    if order.driver.present? && (current_user.admin? || %w[accepted shopping delivering delivered].include?(order.status))
      json[:driver] = {
        id: order.driver.id.to_s,
        name: extract_first_name(order.driver.name), # First name only for privacy
        phone: order.driver.phone
      }
      
      # Add vehicle information if driver has a verified vehicle
      if order.driver.vehicle&.verified?
        vehicle = order.driver.vehicle
        json[:vehicle] = {
          id: vehicle.id.to_s,
          make: vehicle.make,
          model: vehicle.model,
          year: vehicle.year,
          color: vehicle.color,
          licensePlate: vehicle.license_plate,
          vehicleType: vehicle.vehicle_type,
          displayName: vehicle.display_name,
          fullDescription: vehicle.full_description
        }
      end
    end
    
    # Add driver-specific information for drivers
    if for_driver
      delivery_details = calculate_driver_details(order)
      json.merge!(delivery_details)
      
      # Add customer information for drivers (first name only for privacy)
      json[:customerFirstName] = extract_first_name(order.user.name)
      json[:customerPhone] = order.user.phone # Drivers need this to contact customer
      
      # Add store information for drivers
      if order.assigned_store
        json[:storeAddress] = order.assigned_store.address
        json[:storePhone] = order.assigned_store.phone
      end
    end
    
    json
  end

  def order_item_json(order_item)
    product = order_item.product
    {
      id: order_item.id.to_s,
      itemId: order_item.product_id.to_s,
      product: {
        id: product.id.to_s,
        name: product.name,
        price: product.price.to_f,
        unit: product.unit&.name || 'unit',
        image_url: product.image_url,
        category: product.product_categories.includes(:category).first&.category&.name || 'General'
      },
      quantity: order_item.quantity,
      price: order_item.price.to_f,
      status: order_item.status,
      foundQuantity: order_item.found_quantity,
      notes: order_item.notes,
      substituteItem: order_item.substitute_product&.id&.to_s
    }
  end

  def calculate_driver_details(order)
    # Use stored delivery details if available (from customer checkout)
    if order.assigned_store_id.present? && order.store_distance_miles.present?
      use_stored_delivery_details(order)
    else
      # Fallback to calculated values if stored data is missing
      fallback_driver_details(order)
    end
  end

  def use_stored_delivery_details(order)
    # Use delivery details that were calculated and stored during checkout
    estimated_payout = if order.estimated_payout.present?
      order.estimated_payout.to_f
    else
      # Use a reasonable calculation: base rate + portion of delivery fee + tip
      base_rate = 6.00 # Base driver fee
      delivery_portion = (order.delivery_fee || 6.99) * 0.7 # Driver gets 70% of delivery fee
      tip_amount = order.tip_amount || 0
      (base_rate + delivery_portion + tip_amount).round(2).to_f
    end
    
    {
      storeName: order.store_name || order.assigned_store&.name || 'Store',
      deliveryDistance: order.store_distance_miles&.to_f || 5.0, # Store to customer distance
      estimatedTime: calculate_realistic_delivery_time(order),
      estimatedPayout: estimated_payout
    }
  end

  def fallback_driver_details(order)
    # Get first active store as fallback
    store = Store.where(active: true).first
    
    # Calculate estimated payout based on order value and delivery fee
    estimated_payout = if order.estimated_payout.present?
      order.estimated_payout.to_f
    else
      # Use a reasonable calculation: base rate + portion of delivery fee + tip
      base_rate = 6.00 # Base driver fee
      delivery_portion = (order.delivery_fee || 6.99) * 0.7 # Driver gets 70% of delivery fee
      tip_amount = order.tip_amount || 0
      (base_rate + delivery_portion + tip_amount).round(2).to_f
    end
    
    {
      storeName: store&.name || 'Store',
      deliveryDistance: 5.0, # Reasonable fallback for Guam (most deliveries are 3-8 miles)
      estimatedTime: calculate_realistic_delivery_time(order),
      estimatedPayout: estimated_payout
    }
  end

  def format_delivery_address(delivery_address)
    case delivery_address
    when String
      delivery_address
    when Hash
      # Build address string from components (handle both string and symbol keys)
      address_parts = []
      street = delivery_address[:streetAddress] || delivery_address['streetAddress']
      apartment = delivery_address[:apartmentUnit] || delivery_address['apartmentUnit']
      city = delivery_address[:city] || delivery_address['city']
      state = delivery_address[:state] || delivery_address['state']
      zip = delivery_address[:zipCode] || delivery_address['zipCode']
      
      address_parts << street if street.present?
      address_parts << apartment if apartment.present?
      address_parts << city if city.present?
      address_parts << state if state.present?
      address_parts << zip if zip.present?
      
      address_parts.join(', ')
    else
      delivery_address.to_s
    end
  end

  # Helper method to extract first name from full name
  def extract_first_name(full_name)
    return 'Customer' if full_name.blank?
    
    # Split by whitespace and take first word, then capitalize
    first_name = full_name.strip.split(/\s+/).first
    first_name.present? ? first_name.capitalize : 'Customer'
  end

  # Fast delivery details setup with fallback values (no external API calls)
  def ensure_fast_delivery_details(order)
    # Skip if delivery details are already provided
    return if order.assigned_store_id.present? && order.store_distance_miles.present?
    
    # Skip if no delivery address
    return unless order.delivery_address.present?
    
    # Use the first active store as fallback (most stores in Guam serve the whole island)
    fallback_store = Store.where(active: true).first
    if fallback_store
      order.assigned_store_id = fallback_store.id
      order.store_name = fallback_store.name
      order.store_distance_miles = 5.0 # Reasonable average for Guam
      order.estimated_delivery_minutes = 30 # Reasonable average
      
      # Calculate and store estimated payout
      calculate_and_store_estimated_payout(order)
    end
  end

  # Helper method to ensure delivery details are stored in order
  def ensure_delivery_details_stored(order)
    # Skip if delivery details are already provided
    return if order.assigned_store_id.present? && order.store_distance_miles.present?
    
    # Skip if no delivery address
    return unless order.delivery_address.present?
    
    begin
      # Calculate delivery details
      address_string = format_delivery_address(order.delivery_address)
      delivery_result = DistanceCalculator.calculate_delivery_with_details(address_string)
      
      if delivery_result[:success] && delivery_result[:closest_store] && delivery_result[:distance_details]
        order.assigned_store_id = delivery_result[:closest_store].id
        order.store_name = delivery_result[:closest_store].name
        order.store_distance_miles = delivery_result[:distance_details][:distance_miles]
        order.estimated_delivery_minutes = delivery_result[:distance_details][:duration_text]&.scan(/\d+/)&.first&.to_i || 30
      else
        # Fallback to closest store from Google Maps result or first available store
        fallback_store = delivery_result[:closest_store] || Store.where(active: true).first
        if fallback_store
          order.assigned_store_id = fallback_store.id
          order.store_name = fallback_store.name
          order.store_distance_miles = 5.0 # Fallback distance
          order.estimated_delivery_minutes = 30 # Fallback time
          Rails.logger.info "Using fallback delivery details for order: store=#{fallback_store.name}"
        end
      end
      
      # Calculate and store estimated payout
      calculate_and_store_estimated_payout(order)
    rescue => e
      Rails.logger.error "Failed to calculate delivery details for order: #{e.message}"
      # Set fallback values so order creation doesn't fail
      fallback_store = Store.where(active: true).first
      if fallback_store
        order.assigned_store_id = fallback_store.id
        order.store_name = fallback_store.name
        order.store_distance_miles = 5.0
        order.estimated_delivery_minutes = 30
      end
      
      # Calculate payout even with fallback values
      calculate_and_store_estimated_payout(order)
    end
  end
  
  # Calculate and store the estimated payout for drivers
  def calculate_and_store_estimated_payout(order)
    return unless order.delivery_fee.present? && order.tip_amount.present?
    
    base_rate = 6.00 # Base driver fee
    delivery_portion = order.delivery_fee * 0.7 # Driver gets 70% of delivery fee
    tip_amount = order.tip_amount
    
    order.estimated_payout = (base_rate + delivery_portion + tip_amount).round(2)
  end
  
  # Calculate realistic delivery time including shopping and driving
  def calculate_realistic_delivery_time(order)
    # Get the actual Google Maps driving time (store to customer)
    driving_time = order.estimated_delivery_minutes || 30
    
    # Calculate shopping time based on number of items
    item_count = order.order_items.count
    shopping_time = calculate_shopping_time(item_count)
    
    # Total time: shopping + driving
    total_time = shopping_time + driving_time
    
    # Round to nearest 5 minutes for cleaner display
    (total_time / 5.0).round * 5
  end
  
  # Calculate shopping time based on number of items
  def calculate_shopping_time(item_count)
    return 10 if item_count <= 0 # Minimum 10 minutes
    
    # Shopping time calculation:
    # - Base time: 8 minutes (finding parking, getting cart, checkout)
    # - Per item: 2 minutes average (finding, checking quality, bagging)
    # - Extra time for large orders (items get harder to find)
    
    base_time = 8
    per_item_time = 2
    
    # Add complexity factor for larger orders
    complexity_factor = if item_count > 20
      1.3 # 30% longer for very large orders
    elsif item_count > 10
      1.15 # 15% longer for medium orders
    else
      1.0 # No extra time for small orders
    end
    
    shopping_time = (base_time + (item_count * per_item_time)) * complexity_factor
    shopping_time.round
  end

  # Update driver statistics when an order is delivered
  def update_driver_stats_for_delivery(order)
    return unless order.driver.present? && order.estimated_payout.present?
    
    today = Date.current
    
    # Find or create driver stat record for today
    driver_stat = DriverStat.find_or_create_by(
      user: order.driver,
      date: today
    ) do |stat|
      stat.total_deliveries = 0
      stat.total_earnings = 0
      stat.total_ratings = 0
      stat.average_rating = nil
      stat.tips = 0
      stat.base_pay = 0
      stat.bonuses = 0
      stat.expenses = 0
      stat.hours_online = 0
      stat.orders_offered = 0
      stat.orders_accepted = 0
    end
    
    # Calculate earnings breakdown from actual order data
    order_tips = order.tip_amount || 0
    order_base_pay = order.estimated_payout - order_tips
    
    # Update the stats with real data
    driver_stat.total_deliveries += 1
    driver_stat.total_earnings += order.estimated_payout
    driver_stat.tips += order_tips
    driver_stat.base_pay += order_base_pay
    driver_stat.orders_accepted += 1  # This order was accepted and completed
    
    # Save the updated stats
    driver_stat.save!
    
    Rails.logger.info "Updated driver stats for driver #{order.driver.id}: +1 delivery, +$#{order.estimated_payout} earnings (Tips: $#{order_tips}, Base: $#{order_base_pay})"
  rescue => e
    Rails.logger.error "Failed to update driver stats for order #{order.id}: #{e.message}"
    # Don't raise the error to avoid breaking the order status update
  end

end 