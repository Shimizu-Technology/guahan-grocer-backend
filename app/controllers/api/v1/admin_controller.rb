class Api::V1::AdminController < ApplicationController
  before_action :ensure_admin!

  # GET /api/v1/admin/dashboard
  def dashboard
    stats = calculate_dashboard_stats
    recent_activity = get_recent_activity
    
    render json: {
      stats: stats,
      recent_activity: recent_activity
    }
  end

  # POST /api/v1/admin/update_weight_based_products
  def update_weight_based_products
    begin
      # Define weight-based products with their pricing
      weight_based_products = [
        {
          name: 'Cucumber',
          price_per_unit: 4.79,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 5.0
        },
        {
          name: 'Carrots', 
          price_per_unit: 1.19,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 5.0
        },
        {
          name: 'Baby Bokchoy',
          price_per_unit: 2.19,
          weight_unit: 'lb', 
          min_weight: 0.5,
          max_weight: 3.0
        },
        {
          name: 'Yellow Onions',
          price_per_unit: 0.89,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 5.0
        },
        {
          name: 'Red Onions',
          price_per_unit: 1.39,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 5.0
        },
        {
          name: 'White Onions',
          price_per_unit: 1.49,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 5.0
        },
        {
          name: 'Large Tomatos',
          price_per_unit: 1.49,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 5.0
        },
        {
          name: 'Red Leaf Lettuce',
          price_per_unit: 3.29,
          weight_unit: 'lb',
          min_weight: 0.5,
          max_weight: 2.0
        }
      ]

      updated_count = 0
      not_found = []

      weight_based_products.each do |product_data|
        product = Product.find_by(name: product_data[:name])
        
        if product
          product.update!(
            weight_based: true,
            price_per_unit: product_data[:price_per_unit],
            weight_unit: product_data[:weight_unit],
            min_weight: product_data[:min_weight],
            max_weight: product_data[:max_weight]
          )
          updated_count += 1
        else
          not_found << product_data[:name]
        end
      end

      render json: {
        success: true,
        message: "Updated #{updated_count} products as weight-based",
        updated_count: updated_count,
        not_found: not_found
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/admin/sms_report
  def sms_report
    spending_report = SmsCostOptimizer.daily_spending_report
    
    # Get recent SMS messages for debugging
    recent_sms = SmsMessage.order(created_at: :desc)
                          .limit(20)
                          .select(:id, :phone, :status, :created_at, :sent_at)
    
    # Calculate SMS stats
    today_start = Date.current.beginning_of_day
    today_end = Date.current.end_of_day
    
    sms_stats = {
      sent_today: SmsMessage.where(created_at: today_start..today_end, status: 'sent').count,
      failed_today: SmsMessage.where(created_at: today_start..today_end, status: 'failed').count,
      total_sent: SmsMessage.where(status: 'sent').count,
      total_failed: SmsMessage.where(status: 'failed').count
    }
    
    render json: {
      spending_report: spending_report,
      sms_stats: sms_stats,
      recent_sms: recent_sms.map { |sms| 
        {
          id: sms.id,
          phone: sms.phone.gsub(/(\d{3})\d{4}(\d{4})/, '\1****\2'), # Mask phone for privacy
          status: sms.status,
          created_at: sms.created_at,
          sent_at: sms.sent_at
        }
      }
    }
  end

  # POST /api/v1/admin/scan_product
  def scan_product
    gtin = params[:gtin]&.strip
    Rails.logger.info "🔍 Admin scanning product with GTIN: #{gtin}"
    
    if gtin.blank?
      Rails.logger.warn "❌ Scan failed: GTIN is blank"
      return render json: { error: 'GTIN is required' }, status: :bad_request
    end

    # Check if product already exists
    Rails.logger.info "🔍 Checking if product exists in database..."
    existing_product = Product.find_by_gtin(gtin)
    if existing_product
      Rails.logger.info "✅ Product found in database: #{existing_product.name}"
      return render json: {
        exists: true,
        product: format_product_for_admin(existing_product)
      }
    end

    # Fetch from Open Food Facts
    Rails.logger.info "🌐 Fetching from Open Food Facts API for GTIN: #{gtin}"
    start_time = Time.current
    
    begin
      product_data = OpenFoodFactsService.fetch_by_gtin(gtin)
      fetch_duration = ((Time.current - start_time) * 1000).round(2)
      
      if product_data
        Rails.logger.info "✅ Open Food Facts found product: #{product_data[:name]} (#{fetch_duration}ms)"
        render json: {
          exists: false,
          product_data: product_data,
          suggested_name: product_data[:name],
          suggested_brand: product_data[:brand],
          suggested_size: product_data[:size],
          suggested_description: product_data[:description],
          suggested_images: product_data[:image_urls]
        }
      else
        Rails.logger.warn "❌ Open Food Facts: Product not found for GTIN #{gtin} (#{fetch_duration}ms)"
        render json: {
          exists: false,
          product_data: nil,
          message: 'Product not found in Open Food Facts database. Please enter details manually.'
        }
      end
    rescue => e
      fetch_duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.error "💥 Open Food Facts API error for GTIN #{gtin}: #{e.message} (#{fetch_duration}ms)"
      render json: {
        exists: false,
        product_data: nil,
        message: 'Error fetching product data. Please enter details manually.',
        error: e.message
      }
    end
  end

  # POST /api/v1/admin/create_product
  def create_product
    begin
      # Handle both Open Food Facts data and manual entry
      product_params = build_product_params
      category_ids = extract_category_ids
      
      # Create the product - use permit! as fallback for complex nested parameters
      begin
        product_hash = product_params.to_h
      rescue
        product_hash = product_params.permit!.to_h
      end
      product = Product.create!(product_hash)
      
      # Handle category associations
      if category_ids.present?
        product.category_ids = category_ids
      end
      render json: {
        success: true,
        product: format_product_for_admin(product),
        message: 'Product created successfully'
      }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Product validation failed: #{e.record.errors.full_messages.join(', ')}"
      Rails.logger.error "📋 Failed product params: #{product_params.inspect}"
      render json: {
        success: false,
        errors: e.record.errors.full_messages
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "💥 Product creation error: #{e.message}"
      Rails.logger.error "📋 Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: {
        success: false,
        error: 'Failed to create product. Please try again.'
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/admin/products
  def products
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    search = params[:search]&.strip
    
    products = Product.includes(:unit, :categories)
    
    # Apply search filter
    if search.present?
      products = products.where(
        'name ILIKE ? OR brand ILIKE ? OR gtin = ?',
        "%#{search}%", "%#{search}%", search
      )
    end
    
    # For now, return all products without pagination since frontend doesn't handle it
    # TODO: Implement proper pagination in frontend
    
    render json: products.map { |p| format_product_for_admin(p) }
  end

  # GET /api/v1/admin/products/:id
  def product
    product = Product.find(params[:id])
    render json: {
      product: format_product_for_admin(product)
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Product not found'
    }, status: :not_found
  end

  # DELETE /api/v1/admin/products/:id
  def delete_product
    product = Product.find(params[:id])
    
    # Check if product has any pending orders
    pending_orders = product.order_items.joins(:order).where(orders: { status: ['pending', 'confirmed', 'in_progress'] })
    
    if pending_orders.exists?
      render json: {
        error: 'Cannot delete product with pending orders. Please wait for orders to be completed or cancelled.'
      }, status: :unprocessable_entity
      return
    end
    
    product_name = product.name
    product.destroy!
    
    render json: {
      success: true,
      message: "Product '#{product_name}' deleted successfully"
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Product not found'
    }, status: :not_found
  rescue => e
    Rails.logger.error "Failed to delete product: #{e.message}"
    render json: {
      error: 'Failed to delete product. Please try again.'
    }, status: :internal_server_error
  end

  # POST /api/v1/admin/products/:id/enhance
  def enhance_product
    product = Product.find(params[:id])
    
    begin
      off_data = nil
      search_method = nil
      
      # Try GTIN first if available
      if product.gtin.present?
        Rails.logger.info "🔄 Enhancing product #{product.id} (#{product.name}) with GTIN: #{product.gtin}"
        off_data = OpenFoodFactsService.fetch_by_gtin(product.gtin)
        search_method = 'gtin'
      end
      
      # If GTIN search failed or no GTIN, try name-based search
      if off_data.nil? && product.name.present?
        Rails.logger.info "🔍 Trying name-based search for product #{product.id} (#{product.name})"
        search_method = 'name'
        
        # Use existing brand if available, otherwise try to extract from name
        brand_to_search = product.brand.presence
        
        off_data = OpenFoodFactsService.find_best_match(product.name, brand_to_search)
        
        if off_data
          Rails.logger.info "✅ Found match via name search: #{off_data[:name]} (score: #{off_data[:match_score]})"
        end
      end
      
      unless off_data
        error_message = if product.gtin.present?
          'No Open Food Facts data found for this product\'s barcode or name.'
        else
          'No Open Food Facts data found for this product name. Try adding more specific details like brand name.'
        end
        
        render json: {
          success: false,
          error: error_message,
          search_attempted: {
            gtin: product.gtin.present?,
            name: product.name.present?,
            brand: product.brand.present?
          }
        }
        return
      end
      
      # Generate enhancement comparison
      enhancement_data = generate_enhancement_comparison(product, off_data)
      
      render json: {
        success: true,
        product_id: product.id,
        product_name: product.name,
        search_method: search_method,
        match_score: off_data[:match_score],
        gtin: product.gtin,
        enhancement_data: enhancement_data,
        off_data: off_data
      }
      
    rescue => e
      Rails.logger.error "Failed to enhance product: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to fetch enhancement data. Please try again.'
      }, status: :internal_server_error
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Product not found'
    }, status: :not_found
  end

  # POST /api/v1/admin/products/:id/apply_enhancements
  def apply_enhancements
    product = Product.find(params[:id])
    
    begin
      # Get the enhancement data and selected fields from the request
      enhancement_data = params[:enhancement_data]
      selected_fields = params[:selected_fields] || []
      
      Rails.logger.info "🔄 Applying #{selected_fields.length} enhancements to product #{product.id} (#{product.name})"
      
      if selected_fields.empty?
        render json: {
          success: false,
          error: 'No enhancements selected'
        }, status: :unprocessable_entity
        return
      end
      
      # Build update parameters based on selected fields
      update_params = {}
      
      enhancement_data['fields'].each do |field|
        next unless selected_fields.include?(field['key'])
        
        case field['key']
        when 'name'
          update_params[:name] = field['enhanced_value']
        when 'brand'
          update_params[:brand] = field['enhanced_value']
        when 'size'
          update_params[:size] = field['enhanced_value']
        when 'description'
          # Skip description updates - ingredients should not be used as description
          # Description should be marketing-friendly text, not technical ingredients
          next
        when 'serving_size'
          update_params[:serving_size] = field['enhanced_value']
        when 'ingredients_text'
          update_params[:ingredients_text] = field['enhanced_value']
        when 'allergens'
          update_params[:allergens] = field['enhanced_value']
        when 'traces'
          update_params[:traces] = field['enhanced_value']
        when 'off_categories'
          update_params[:off_categories] = field['enhanced_value']
        when 'off_labels'
          update_params[:off_labels] = field['enhanced_value']
        when 'nutriscore_grade'
          # Normalize nutriscore_grade to uppercase for validation
          update_params[:nutriscore_grade] = field['enhanced_value']&.upcase
        when 'nova_group'
          update_params[:nova_group] = field['enhanced_value'].to_i
        when 'packaging'
          update_params[:packaging] = field['enhanced_value']
        when 'image_urls'
          # Merge new images with existing ones
          existing_urls = product.image_urls || []
          new_urls = field['enhanced_value'] || []
          update_params[:image_urls] = (existing_urls + new_urls).uniq
        when 'gtin'
          update_params[:gtin] = field['enhanced_value']
        end
      end
      
      Rails.logger.info "🔄 Update parameters: #{update_params.keys.join(', ')}"
      
      # Update the product
      product.update!(update_params)
      
      Rails.logger.info "✅ Successfully applied #{selected_fields.length} enhancements to product #{product.id}"
      
      # Return the updated product data
      render json: {
        success: true,
        message: "Applied #{selected_fields.length} enhancement#{selected_fields.length != 1 ? 's' : ''} successfully",
        product: format_product_for_admin(product),
        applied_fields: selected_fields
      }
      
    rescue => e
      Rails.logger.error "💥 Failed to apply enhancements: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to apply enhancements. Please try again.'
      }, status: :internal_server_error
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Product not found'
    }, status: :not_found
  end

  private

  def calculate_dashboard_stats
    # Calculate today's date range
    today = Date.current
    today_start = today.beginning_of_day
    today_end = today.end_of_day

    {
      total_orders: Order.count,
      total_customers: User.customer.count,
      active_drivers: User.driver.where(active: true).count,
      revenue_today: Order.where(created_at: today_start..today_end)
                         .where(status: ['delivered'])
                         .sum(:total)
                         .to_f
                         .round(2),
      revenue_total: Order.where(status: ['delivered'])
                         .sum(:total)
                         .to_f
                         .round(2),
      orders_today: Order.where(created_at: today_start..today_end).count,
      pending_orders: Order.where(status: 'pending').count,
      low_stock_products: Product.where('stock_quantity <= ?', 10)
                                .where(track_inventory: true)
                                .count
    }
  end

  def get_recent_activity
    activities = []

    # Recent orders (last 10)
    recent_orders = Order.includes(:user)
                        .order(created_at: :desc)
                        .limit(5)
    
    recent_orders.each do |order|
      activities << {
        type: 'order',
        message: "New order ##{order.id} from #{order.user.name}",
        time: time_ago_in_words(order.created_at),
        timestamp: order.created_at
      }
    end

    # Recent user registrations (last 5)
    recent_users = User.customer
                      .order(created_at: :desc)
                      .limit(3)
    
    recent_users.each do |user|
      activities << {
        type: 'customer',
        message: "New customer #{user.name} registered",
        time: time_ago_in_words(user.created_at),
        timestamp: user.created_at
      }
    end

    # Low stock alerts (only for products with inventory tracking enabled)
    low_stock = Product.where('stock_quantity <= ?', 10)
                      .where(in_stock: true)
                      .where(track_inventory: true)
                      .limit(3)
    
    low_stock.each do |product|
      activities << {
        type: 'inventory',
        message: "Low stock alert: #{product.name} (#{product.stock_quantity} left)",
        time: 'Now',
        timestamp: Time.current
      }
    end

    # Sort by timestamp and return most recent
    activities.sort_by { |a| a[:timestamp] }
             .reverse
             .first(8)
             .map { |a| a.except(:timestamp) }
  end

  def time_ago_in_words(time)
    seconds = Time.current - time
    
    case seconds
    when 0..59
      "#{seconds.to_i} seconds ago"
    when 60..3599
      "#{(seconds / 60).to_i} minutes ago"
    when 3600..86399
      "#{(seconds / 3600).to_i} hours ago"
    else
      "#{(seconds / 86400).to_i} days ago"
    end
  end

  # Helper methods for barcode scanning
      def format_product_for_admin(product)
        {
          id: product.id,
          name: product.name,
          brand: product.brand,
          size: product.size,
          gtin: product.gtin,
          price: product.price,
          description: product.description,
          
          # Category information
          category: product.categories.first&.name,
          categories: product.categories.map { |cat| { id: cat.id, name: cat.name } },
          
          # Unit information
          unit: product.unit&.name,
          
          # Enhanced Open Food Facts data
          serving_size: product.serving_size,
          ingredients_text: product.ingredients_list,
          allergens: product.allergens_list,
          traces: product.traces,
          off_categories: product.categories_list,
          off_labels: product.labels_list,
          nutriscore_grade: product.nutriscore_display,
          nova_group: product.nova_group,
          nova_display: product.nova_display,
          packaging: product.packaging,
          
          # Images
          image_url: product.primary_image_url,
          image_urls: product.all_image_urls,
          image_ingredients_url: product.image_ingredients_url,
          image_nutrition_url: product.image_nutrition_url,
          has_multiple_images: product.has_multiple_images?,
          
          # Health & Safety indicators
          has_nutrition_data: product.has_nutrition_data?,
          has_allergen_info: product.has_allergen_info?,
          has_health_scores: product.has_health_scores?,
          is_food_product: product.is_food_product?,
          
          # Nutrition (existing)
          calories_per_100g: product.calories_per_100g,
          
          # Product management
          weight_based: product.weight_based?,
          track_inventory: product.track_inventory?,
          in_stock: product.in_stock?,
          stock_quantity: product.stock_quantity,
          created_at: product.created_at,
          updated_at: product.updated_at
        }
      end

  def build_product_params
    # Get the default unit (usually "Each")
    default_unit = Unit.find_by(name: 'Each') || Unit.first
    
    # Handle FormData parameters (comes as _parts) vs regular JSON parameters
    if params[:_parts].present?
      # FormData - convert _parts array to hash
      product_hash = {}
      params[:_parts].each do |part|
        key = part[0]
        value = part[1]
        
        # Remove 'product[' prefix and handle array parameters
        if key.start_with?('product[')
          # Handle array parameters like product[category_ids][] or product[image_urls][]
          if key.end_with?('][]')
            # Extract key name from product[key_name][]
            clean_key = key[8..-4] # Remove 'product[' and '][]'
            product_hash[clean_key] ||= []
            product_hash[clean_key] << value
          elsif key.end_with?(']')
            # Regular parameter like product[name]
            clean_key = key[8..-2] # Remove 'product[' and ']'
            product_hash[clean_key] = value
          end
        end
      end
      
      # Convert to ActionController::Parameters for permit
      product_params = ActionController::Parameters.new(product_hash)
    else
      # Regular JSON parameters
      product_params = params.require(:product)
    end
    
    permitted_params = product_params.permit(
      :gtin, :name, :brand, :size, :description, :price, :unit_id,
      :weight_based, :price_per_unit, :weight_unit, :min_weight, :max_weight,
      :track_inventory, :stock_quantity, :in_stock,
      # Enhanced Open Food Facts fields
      :serving_size, :ingredients_text, :allergens, :traces,
      :off_categories, :off_labels, :nutriscore_grade, :nova_group,
      :packaging, :image_ingredients_url, :image_nutrition_url, :nutrition_data,
      image_urls: []
    )
    
    # Remove category_ids from product params since we handle it separately
    permitted_params.delete(:category_ids)
    
    # Set defaults
    permitted_params[:unit_id] = permitted_params[:unit_id] || default_unit&.id
    permitted_params[:track_inventory] = permitted_params[:track_inventory] || false
    permitted_params[:weight_based] = permitted_params[:weight_based] || false
    permitted_params[:in_stock] = permitted_params[:in_stock] != false # Default to true
    
    # Handle image_urls array - ensure it's a proper array for PostgreSQL
    if permitted_params[:image_urls].present?
      permitted_params[:image_urls] = permitted_params[:image_urls].compact.reject(&:blank?)
    else
      permitted_params[:image_urls] = []
    end
    
    # Handle nutrition_data JSON
    if permitted_params[:nutrition_data].present?
      # If it's a string (from FormData), parse it as JSON
      if permitted_params[:nutrition_data].is_a?(String)
        begin
          permitted_params[:nutrition_data] = JSON.parse(permitted_params[:nutrition_data])
        rescue JSON::ParserError
          Rails.logger.warn "Failed to parse nutrition_data JSON: #{permitted_params[:nutrition_data]}"
          permitted_params[:nutrition_data] = {}
        end
      else
        # If it's already a hash, use it as-is
        permitted_params[:nutrition_data] = permitted_params[:nutrition_data].to_h
      end
    else
      permitted_params[:nutrition_data] = {}
    end
    
    permitted_params
  end

  def extract_category_ids
    # Handle FormData parameters (comes as _parts) vs regular JSON parameters
    if params[:_parts].present?
      # FormData - extract category_ids from _parts
      category_ids = []
      params[:_parts].each do |part|
        key = part[0]
        value = part[1]
        
        if key == 'product[category_ids][]'
          category_ids << value
        end
      end
      category_ids
    else
      # Regular JSON parameters
      params.dig(:product, :category_ids) || []
    end
  end

  def generate_enhancement_comparison(product, off_data)
    enhancement_fields = []
    
    # Define all enhanceable fields with their priorities and categories
    field_definitions = [
      # Basic Info
      { key: :name, current: product.name, enhanced: off_data[:name], 
        category: 'basic', priority: 'medium', label: 'Product Name' },
      { key: :brand, current: product.brand, enhanced: off_data[:brand], 
        category: 'basic', priority: 'high', label: 'Brand' },
      { key: :size, current: product.size, enhanced: off_data[:size], 
        category: 'basic', priority: 'medium', label: 'Size/Quantity' },
      # Skip description - ingredients should not be used as product description
      # { key: :description, current: product.description, enhanced: off_data[:description], 
      #   category: 'basic', priority: 'low', label: 'Description' },
      
      # Safety Critical
      { key: :allergens, current: product.allergens, enhanced: off_data[:allergens], 
        category: 'safety', priority: 'critical', label: 'Allergens' },
      { key: :traces, current: product.traces, enhanced: off_data[:traces], 
        category: 'safety', priority: 'high', label: 'May Contain (Traces)' },
      
      # Nutrition & Health
      { key: :serving_size, current: product.serving_size, enhanced: off_data[:serving_size], 
        category: 'nutrition', priority: 'medium', label: 'Serving Size' },
      { key: :ingredients_text, current: product.ingredients_text, enhanced: off_data[:ingredients_text], 
        category: 'nutrition', priority: 'high', label: 'Ingredients' },
      { key: :nutriscore_grade, current: product.nutriscore_grade, enhanced: off_data[:nutriscore_grade], 
        category: 'health', priority: 'medium', label: 'Nutri-Score' },
      { key: :nova_group, current: product.nova_group, enhanced: off_data[:nova_group], 
        category: 'health', priority: 'medium', label: 'NOVA Group' },
      
      # Classification
      { key: :off_categories, current: product.off_categories, enhanced: off_data[:off_categories], 
        category: 'classification', priority: 'low', label: 'Open Food Facts Categories' },
      { key: :off_labels, current: product.off_labels, enhanced: off_data[:off_labels], 
        category: 'classification', priority: 'low', label: 'Labels' },
      
      # Environmental
      { key: :packaging, current: product.packaging, enhanced: off_data[:packaging], 
        category: 'environmental', priority: 'low', label: 'Packaging' },
      
      # Images
      { key: :image_ingredients_url, current: product.image_ingredients_url, enhanced: off_data[:image_ingredients_url], 
        category: 'media', priority: 'medium', label: 'Ingredients Image' },
      { key: :image_nutrition_url, current: product.image_nutrition_url, enhanced: off_data[:image_nutrition_url], 
        category: 'media', priority: 'medium', label: 'Nutrition Image' }
    ]
    
    # Process each field and determine enhancement status
    field_definitions.each do |field|
      current_value = clean_for_comparison(field[:current])
      enhanced_value = clean_for_comparison(field[:enhanced])
      
      # Skip if enhanced value is empty
      next if enhanced_value.blank?
      
      # Determine enhancement status
      status = determine_enhancement_status(current_value, enhanced_value, field[:priority])
      
      # Only include fields that have potential enhancements
      if status != 'no_change'
        enhancement_fields << {
          key: field[:key],
          label: field[:label],
          category: field[:category],
          priority: field[:priority],
          status: status,
          current_value: current_value,
          enhanced_value: enhanced_value,
          recommended: should_recommend_update(status, field[:priority])
        }
      end
    end
    
    # Handle image_urls array separately (special case)
    if off_data[:image_urls].present?
      current_images = product.image_urls || []
      enhanced_images = off_data[:image_urls] || []
      
      # Find new images not in current set
      new_images = enhanced_images - current_images
      
      if new_images.any?
        enhancement_fields << {
          key: :image_urls,
          label: 'Product Images',
          category: 'media',
          priority: 'medium',
          status: 'addition',
          current_value: current_images,
          enhanced_value: enhanced_images,
          new_images: new_images,
          recommended: true
        }
      end
    end
    
    # Handle nutrition_data (complex object)
    if off_data[:nutrition_data].present?
      current_nutrition = product.nutrition_data || {}
      enhanced_nutrition = off_data[:nutrition_data] || {}
      
      # Check if there are meaningful nutrition updates
      nutrition_updates = find_nutrition_updates(current_nutrition, enhanced_nutrition)
      
      if nutrition_updates.any?
        enhancement_fields << {
          key: :nutrition_data,
          label: 'Nutrition Data',
          category: 'nutrition',
          priority: 'high',
          status: 'update',
          current_value: current_nutrition,
          enhanced_value: enhanced_nutrition,
          updates: nutrition_updates,
          recommended: true
        }
      end
    end
    
    # Sort by priority and category
    priority_order = { 'critical' => 0, 'high' => 1, 'medium' => 2, 'low' => 3 }
    enhancement_fields.sort_by! { |field| [priority_order[field[:priority]] || 4, field[:label]] }
    
    {
      total_enhancements: enhancement_fields.length,
      critical_updates: enhancement_fields.count { |f| f[:priority] == 'critical' },
      recommended_updates: enhancement_fields.count { |f| f[:recommended] },
      fields: enhancement_fields
    }
  end

  def clean_for_comparison(value)
    return nil if value.blank?
    value.to_s.strip
  end

  def determine_enhancement_status(current, enhanced, priority)
    return 'no_change' if enhanced.blank?
    
    if current.blank?
      'addition'  # Adding new data
    elsif current != enhanced
      'update'    # Updating existing data
    else
      'no_change' # Same data
    end
  end

  def should_recommend_update(status, priority)
    case status
    when 'addition'
      true  # Always recommend adding missing data
    when 'update'
      priority == 'critical' || priority == 'high'  # Only recommend updates for important fields
    else
      false
    end
  end

  def find_nutrition_updates(current, enhanced)
    updates = []
    
    # Key nutrition fields to check
    nutrition_fields = [
      'energy_kcal_100g', 'fat_100g', 'saturated_fat_100g', 
      'carbohydrates_100g', 'sugars_100g', 'proteins_100g', 'salt_100g'
    ]
    
    nutrition_fields.each do |field|
      current_val = current[field]
      enhanced_val = enhanced[field]
      
      if enhanced_val.present? && (current_val.blank? || current_val != enhanced_val)
        updates << {
          field: field,
          current: current_val,
          enhanced: enhanced_val,
          status: current_val.blank? ? 'addition' : 'update'
        }
      end
    end
    
    updates
  end
end 