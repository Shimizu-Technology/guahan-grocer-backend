#!/usr/bin/env ruby
# Fix items with 0% variance that should be auto-approved

puts "🔧 Fixing items with 0% variance that need auto-approval"
puts "=" * 60

# Find all weight-based order items with 0% variance that haven't been approved yet
items_to_fix = OrderItem.joins(:product)
                       .where(products: { weight_based: true })
                       .where(variance_percentage: 0.0)
                       .where(variance_approved: nil)
                       .where.not(actual_weight: nil)

puts "Found #{items_to_fix.count} items with 0% variance needing auto-approval:"
puts

items_to_fix.each do |item|
  puts "📦 Order ##{item.order_id} - #{item.product.name}"
  puts "   Estimated: #{item.estimated_weight} #{item.product.weight_unit}"
  puts "   Actual: #{item.actual_weight} #{item.product.weight_unit}"
  puts "   Variance: #{item.variance_percentage}%"
  puts "   Current approval status: #{item.variance_approved}"
  
  begin
    # Auto-approve the 0% variance
    item.approve_variance!('auto')
    
    puts "   ✅ Auto-approved 0% variance"
    
    # Create auto-approval event
    item.order.add_event('variance_auto_approved', nil, nil, {
      item_id: item.id,
      item_name: item.product.name,
      variance_percentage: "0.0",
      estimated_weight: item.estimated_weight,
      actual_weight: item.actual_weight,
      weight_unit: item.product.weight_unit,
      reason: "Zero variance auto-approval fix"
    })
    
  rescue => e
    puts "   ❌ Failed to auto-approve: #{e.message}"
  end
  
  puts
end

puts "🔍 Verification - checking all weight-based items in shopping orders:"
puts

shopping_orders = Order.where(status: 'shopping')
shopping_orders.each do |order|
  puts "Order ##{order.id}:"
  
  completed_items = order.order_items.select do |item|
    if item.weight_based?
      item.actual_weight.present? && 
      (item.variance_approved == true || item.needs_customer_approval? == false)
    else
      item.found_quantity.present? && item.found_quantity > 0
    end
  end
  
  puts "  Progress: #{completed_items.length}/#{order.order_items.count} items complete"
  
  order.order_items.each do |item|
    status_icon = if item.weight_based?
      (item.actual_weight.present? && (item.variance_approved == true || item.needs_customer_approval? == false)) ? "✅" : "❌"
    else
      (item.found_quantity.present? && item.found_quantity > 0) ? "✅" : "❌"
    end
    
    puts "    #{status_icon} #{item.product.name}"
    if item.weight_based?
      puts "       variance_approved: #{item.variance_approved}"
      puts "       needs_approval: #{item.needs_customer_approval?}"
    end
  end
  puts
end

puts "✅ Zero variance fix complete!"
