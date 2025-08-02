class DistanceCalculator
  include HTTParty
  base_uri 'https://maps.googleapis.com/maps/api'

  GOOGLE_MAPS_API_KEY = ENV['GOOGLE_MAPS_API_KEY']

  # Address correction for known Google Maps geocoding issues
  PROBLEMATIC_ADDRESS_CORRECTIONS = {
    # Canton Tasi addresses in Yona get mislocated to Sinajana area
    /\b(\d+\s+)?north\s+canton\s+tasi.*yona/i => "Yona, GU 96914",
    /\bcanton\s+tasi.*yona/i => "Yona, GU 96914",
    
    # Chalan Pale Ramon Lagu in Yigo is not found by Google Maps API
    # Use nearby area in Yigo for accurate distance calculation
    /\b(\d+\s+)?chalan\s+pale['']?\s+ramon\s+lagu.*yigo/i => "Chalan San Vicente, Yigo, GU 96929",
    /\bchalan\s+pale['']?\s+ramon\s+lago.*yigo/i => "Chalan San Vicente, Yigo, GU 96929",
    
    # Add more corrections as needed
    # /problematic_pattern/i => "corrected_address"
  }.freeze

  # Get corrected address if known problematic pattern is detected
  def self.get_corrected_address(address)
    PROBLEMATIC_ADDRESS_CORRECTIONS.each do |pattern, correction|
      if address.match?(pattern)
        Rails.logger.info "Address correction applied: '#{address}' → '#{correction}'"
        return {
          corrected_address: correction,
          original_address: address,
          correction_applied: true,
          reason: "Known Google Maps geocoding issue detected"
        }
      end
    end
    
    { corrected_address: address, correction_applied: false }
  end

  # Comprehensive delivery calculation that returns fee, store, and error status
  def self.calculate_delivery_with_details(customer_address)
    # Apply address correction first
    correction_result = get_corrected_address(customer_address)
    final_address = correction_result[:corrected_address]
    
    # Find closest store (only call this once!)
    closest_store = find_closest_store_to(final_address)
    
    unless closest_store
      return {
        success: false,
        error: "No stores available",
        delivery_fee: default_delivery_fee,
        closest_store: nil,
        distance_details: nil
      }
    end

    # Calculate distance from closest store using corrected address
    distance_data = calculate_distance(closest_store.full_address, final_address)
    
    unless distance_data
      return {
        success: false,
        error: "Address not found - please check your address and try again",
        delivery_fee: default_delivery_fee,
        closest_store: closest_store,
        distance_details: nil
      }
    end

    # Calculate fee based on distance
    distance_miles = distance_data[:distance_miles]
    base_fee = 6.99
    per_mile_rate = 0.85

    delivery_fee = (base_fee + (distance_miles * per_mile_rate)).round(2)

    result = {
      success: true,
      delivery_fee: delivery_fee,
      closest_store: closest_store,
      distance_details: {
        distance_text: distance_data[:distance_text],
        duration_text: distance_data[:duration_text],
        distance_miles: distance_data[:distance_miles],
        store_name: closest_store.name
      }
    }

    # Add address correction info if correction was applied
    if correction_result[:correction_applied]
      result[:address_correction] = {
        original_address: correction_result[:original_address],
        corrected_address: correction_result[:corrected_address],
        reason: correction_result[:reason]
      }
    end

    result
  end

  class << self
    def calculate_distance(origin, destination)
      return nil unless GOOGLE_MAPS_API_KEY.present?

      # Create cache key based on normalized addresses
      cache_key = "distance_calc:#{normalize_address(origin)}:#{normalize_address(destination)}"
      
      # Try to get from cache first (24 hour expiry)
      cached_result = Rails.cache.read(cache_key)
      return cached_result if cached_result

      begin
        response = get('/distancematrix/json', {
          query: {
            origins: format_address(origin),
            destinations: format_address(destination),
            units: 'imperial',
            mode: 'driving',
            key: GOOGLE_MAPS_API_KEY
          }
        })

        if response.success? && response['status'] == 'OK'
          element = response.dig('rows', 0, 'elements', 0)
          
          if element && element['status'] == 'OK'
            result = {
              distance_miles: meters_to_miles(element.dig('distance', 'value')),
              duration_minutes: seconds_to_minutes(element.dig('duration', 'value')),
              distance_text: element.dig('distance', 'text'),
              duration_text: element.dig('duration', 'text')
            }
            
            # Cache the result for 24 hours
            Rails.cache.write(cache_key, result, expires_in: 24.hours)
            result
          else
            Rails.logger.error "Google Maps API element error: #{element}"
            nil
          end
        else
          Rails.logger.error "Google Maps API error: #{response['error_message']}"
          nil
        end
      rescue => e
        Rails.logger.error "Distance calculation error: #{e.message}"
        nil
      end
    end

    def calculate_delivery_fee(customer_address)
      # Find closest store to customer
      closest_store = Store.closest_to(customer_address)
      return default_delivery_fee unless closest_store

      # Calculate distance from closest store
      distance_data = calculate_distance(closest_store.full_address, customer_address)
      return default_delivery_fee unless distance_data

      # Calculate fee based on distance
      distance_miles = distance_data[:distance_miles]
      base_fee = 6.99
      per_mile_rate = 0.85

      (base_fee + (distance_miles * per_mile_rate)).round(2)
    end

    def find_closest_store_to(customer_address)
      active_stores = Store.active
      return nil if active_stores.empty?
      return active_stores.first if active_stores.count == 1

      # For Guam's geography, try to find the closest store intelligently
      # This avoids multiple slow API calls during order creation
      closest_store = find_closest_store_optimized(active_stores, customer_address)
      
      closest_store || active_stores.first
    end

    # Optimized store finding that minimizes API calls
    def find_closest_store_optimized(stores, customer_address)
      # If we only have a few stores, check distances with caching (no artificial delays)
      if stores.count <= 3
        closest_store = nil
        shortest_distance = Float::INFINITY

        stores.each do |store|
          distance_data = calculate_distance(store.full_address, customer_address)
          next unless distance_data

          if distance_data[:distance_miles] < shortest_distance
            shortest_distance = distance_data[:distance_miles]
            closest_store = store
          end
        end

        return closest_store
      end

      # For many stores, use geographic approximation first
      # Most Guam addresses contain village names that can help identify the closest area
      customer_village = extract_village_from_address(customer_address)
      
      if customer_village
        # Try to find a store in or near the same village
        preferred_store = stores.find do |store|
          store.address&.downcase&.include?(customer_village.downcase) ||
          store.name&.downcase&.include?(customer_village.downcase)
        end
        
        return preferred_store if preferred_store
      end

      # Fallback: just use the first available store
      # The background job will calculate the accurate closest store later
      stores.first
    end

    # Extract village name from Guam address for geographic approximation
    def extract_village_from_address(address)
      # Common Guam villages
      villages = %w[
        Agana Agat Asan Barrigada Chalan Dededo Hagatna Inarajan
        Mangilao Merizo Mongmong Ordot Piti Santa Sinajana Tamuning
        Toto Umatac Yigo Yona
      ]
      
      address_lower = address.to_s.downcase
      villages.find { |village| address_lower.include?(village.downcase) }
    end

    # Validate if distance calculation results seem reasonable for Guam geography
    def self.validate_distance_result(address, closest_store, distance_miles)
      # Guam is about 30 miles long, so any distance over 25 miles is suspicious
      if distance_miles > 25
        Rails.logger.warn "Suspicious distance calculation: #{distance_miles} miles from #{address} to #{closest_store.name}"
        return { valid: false, reason: "Distance too large for Guam geography" }
      end

      # Check for known problematic addresses that Google Maps mislocates
      problematic_patterns = [
        /canton\s+tasi/i,
        /north\s+canton/i
      ]
      
      if problematic_patterns.any? { |pattern| address.match?(pattern) }
        Rails.logger.warn "Potentially problematic address detected: #{address}"
        return { 
          valid: false, 
          reason: "Address may be mislocated by Google Maps",
          suggestion: "Try using just the village name (e.g., 'Yona, GU 96914')"
        }
      end

      { valid: true }
    end

    # Enhanced delivery fee calculation with validation
    def self.calculate_delivery_fee_with_validation(address)
      closest_store = find_closest_store_to(address)
      return 6.99 unless closest_store # Fallback fee

      distance_data = calculate_distance(closest_store.address, address)
      return 6.99 unless distance_data # Fallback fee

      distance_miles = distance_data[:distance_miles]
      validation = validate_distance_result(address, closest_store, distance_miles)
      
      unless validation[:valid]
        Rails.logger.warn "Distance validation failed: #{validation[:reason]}"
        # You could return an error here or use a fallback
      end

      calculate_fee_from_distance(distance_miles)
    end

    # Enhanced delivery fee calculation with address correction
    def self.calculate_delivery_fee_with_correction(address)
      correction_result = get_corrected_address(address)
      final_address = correction_result[:corrected_address]
      
      delivery_fee = calculate_delivery_fee(final_address)
      
      {
        delivery_fee: delivery_fee,
        address_correction: correction_result[:correction_applied] ? {
          original_address: correction_result[:original_address],
          corrected_address: correction_result[:corrected_address],
          reason: correction_result[:reason]
        } : nil
      }
    end

    private

    def normalize_address(address)
      # Create a normalized version for cache keys
      formatted = format_address(address)
      # Remove extra spaces, convert to lowercase, remove special chars for consistent caching
      formatted.to_s.downcase.gsub(/[^\w\s,]/, '').squeeze(' ').strip
    end

    def format_address(address)
      case address
      when String
        address
      when Array
        "#{address[0]},#{address[1]}" # [lat, lng]
      when Hash
        address[:address] || "#{address[:latitude]},#{address[:longitude]}"
      else
        address.to_s
      end
    end

    def meters_to_miles(meters)
      return 0 unless meters
      (meters * 0.000621371).round(2)
    end

    def seconds_to_minutes(seconds)
      return 0 unless seconds
      (seconds / 60.0).round(1)
    end

    def default_delivery_fee
      6.99
    end
  end
end 