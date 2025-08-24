#!/usr/bin/env ruby
# Debug script to analyze order progress calculation

puts "🔍 Debugging Order Progress Calculation"
puts "=" * 50

# Find the most recent order in shopping status
order = Order.where(status: 'shopping').order(:created_at).last

if order.nil?
  puts "❌ No orders found in 'shopping' status"
  exit
end

puts "📋 Order ##{order.id} Analysis:"
puts "  Status: #{order.status}"
puts "  Total items: #{order.order_items.count}"
puts

# Analyze each item
order.order_items.each_with_index do |item, index|
  puts "#{index + 1}. #{item.product.name}"
  puts "   weight_based?: #{item.weight_based?}"
  puts "   status: #{item.status}"
  puts "   found_quantity: #{item.found_quantity}"
  
  if item.weight_based?
    puts "   estimated_weight: #{item.estimated_weight}"
    puts "   actual_weight: #{item.actual_weight}"
    puts "   variance_percentage: #{item.variance_percentage}"
    puts "   variance_approved: #{item.variance_approved}"
    puts "   needs_customer_approval?: #{item.needs_customer_approval?}"
    puts "   weight_verified_at: #{item.weight_verified_at}"
    
    # Check completion status per our logic
    has_actual_weight = item.actual_weight.present?
    variance_ok = item.variance_approved == true || item.needs_customer_approval? == false
    is_complete_weight_based = has_actual_weight && variance_ok
    
    puts "   ✅ Complete (weight-based)?: #{is_complete_weight_based}"
    puts "     - has_actual_weight: #{has_actual_weight}"
    puts "     - variance_ok: #{variance_ok}"
    puts "       - variance_approved: #{item.variance_approved == true}"
    puts "       - needs_approval: #{item.needs_customer_approval?}"
  else
    is_complete_unit_based = item.found_quantity.present? && item.found_quantity > 0
    puts "   ✅ Complete (unit-based)?: #{is_complete_unit_based}"
  end
  
  puts
end

# Calculate progress using our logic
completed_items = order.order_items.select do |item|
  if item.weight_based?
    item.actual_weight.present? && 
    (item.variance_approved == true || item.needs_customer_approval? == false)
  else
    item.found_quantity.present? && item.found_quantity > 0
  end
end

puts "📊 Progress Calculation:"
puts "  Completed items: #{completed_items.length}"
puts "  Total items: #{order.order_items.count}"
puts "  Progress: #{completed_items.length}/#{order.order_items.count}"
puts

# Show the API response structure
puts "🔗 API Response Structure:"
puts "  This is what the frontend receives:"

# Simulate the order_item_json method
order.order_items.each do |item|
  puts "  #{item.product.name}:"
  puts "    foundQuantity: #{item.found_quantity}"
  if item.weight_based?
    weight_info = item.weight_display_info || {}
    puts "    weightInfo:"
    puts "      actualWeight: #{weight_info[:actual_weight]}"
    puts "      varianceApproved: #{weight_info[:variance_approved]}"
    puts "      needsApproval: #{weight_info[:needs_approval]}"
  end
  puts
end
