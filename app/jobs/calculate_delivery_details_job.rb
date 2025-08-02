class CalculateDeliveryDetailsJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    Rails.logger.info "Calculating accurate delivery details for order #{order_id}"

    begin
      # Calculate accurate delivery details using the external API
      address_string = format_delivery_address(order.delivery_address)
      delivery_result = DistanceCalculator.calculate_delivery_with_details(address_string)
      
      if delivery_result[:success] && delivery_result[:closest_store] && delivery_result[:distance_details]
        # Update order with accurate details
        order.update!(
          assigned_store_id: delivery_result[:closest_store].id,
          store_name: delivery_result[:closest_store].name,
          store_distance_miles: delivery_result[:distance_details][:distance_miles],
          estimated_delivery_minutes: delivery_result[:distance_details][:duration_text]&.scan(/\d+/)&.first&.to_i || 30
        )
        
        # Recalculate estimated payout with accurate distance
        calculate_and_store_estimated_payout(order)
        
        Rails.logger.info "Updated delivery details for order #{order_id}: store=#{delivery_result[:closest_store].name}, distance=#{delivery_result[:distance_details][:distance_miles]} miles"
      else
        Rails.logger.warn "Failed to get accurate delivery details for order #{order_id}, keeping fallback values"
      end
    rescue => e
      Rails.logger.error "Error calculating delivery details for order #{order_id}: #{e.message}"
      # Order continues with fallback values - no customer impact
    end
  end

  private

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

  # Calculate and store the estimated payout for drivers
  def calculate_and_store_estimated_payout(order)
    return unless order.delivery_fee.present? && order.tip_amount.present?
    
    base_rate = 6.00 # Base driver fee
    delivery_portion = order.delivery_fee * 0.7 # Driver gets 70% of delivery fee
    tip_amount = order.tip_amount
    
    order.update!(estimated_payout: (base_rate + delivery_portion + tip_amount).round(2))
  end
end