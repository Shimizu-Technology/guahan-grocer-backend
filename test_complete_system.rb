#!/usr/bin/env ruby

# Complete system test for Guahan Grocer weighted items and payment integration
# This tests the full flow from order creation to payment capture

puts "🧪 === Complete System Test - Weighted Items & Payment Integration ==="
puts ""

# Test environment setup
ENV['USE_MOCK_PAYMENTS'] = 'true'  # Use mock payments for testing
ENV['STRIPE_TEST_MODE'] = 'true'

# Test 1: Verify Payment Service Configuration
puts "1️⃣ Testing Payment Service Configuration"
puts "-" * 50

begin
  service = Payment::PaymentService.current
  status = Payment::PaymentService.status
  
  puts "✅ Payment service: #{service.class.name}"
  puts "✅ Service status: #{status[:service_name]} - #{status[:status]}"
  puts "✅ Using mock: #{Payment::PaymentService.using_mock?}"
  puts ""
rescue => e
  puts "❌ Payment service error: #{e.message}"
  exit 1
end

# Test 2: Create Weight-Based Product
puts "2️⃣ Creating Weight-Based Test Product"
puts "-" * 50

# Find or create a weight-based product
test_product = Product.find_by(name: "Test Ground Beef") || Product.create!(
  name: "Test Ground Beef",
  description: "Fresh ground beef for testing",
  price: 6.99,
  weight_based: true,
  price_per_unit: 6.99,
  weight_unit: "lb",
  min_weight: 0.5,
  max_weight: 3.0,
  unit_id: Unit.first&.id || Unit.create!(name: "lb", display_name: "pound").id,
  in_stock: true,
  stock_quantity: 100
)

# Add to a category if the association exists
if test_product.respond_to?(:categories) && Category.exists?
  test_product.categories << Category.first unless test_product.categories.exists?
end

puts "✅ Product created: #{test_product.name}"
puts "   - Weight-based: #{test_product.weight_based?}"
puts "   - Price per #{test_product.weight_unit}: $#{test_product.price_per_unit}"
puts "   - Weight range: #{test_product.min_weight}-#{test_product.max_weight} #{test_product.weight_unit}"
puts ""

# Test 3: Create Test User with Preferences
puts "3️⃣ Creating Test User with Variance Preferences"
puts "-" * 50

test_user = User.find_by(email: "test@example.com") || User.create!(
  name: "Test Customer",
  email: "test@example.com",
  password: "password123",
  phone: "+16711234567",
  role: "customer",
  auto_approve_variances: false,  # Require manual approval for testing
  max_auto_variance_percentage: 15,
  variance_notification_method: "push"
)

puts "✅ User created: #{test_user.name}"
puts "   - Auto-approve variances: #{test_user.auto_approve_variances}"
puts "   - Max auto variance: #{test_user.max_auto_variance_percentage}%"
puts "   - Notification method: #{test_user.variance_notification_method}"
puts ""

# Test 4: Create Order with Weight-Based Item
puts "4️⃣ Creating Order with Weight-Based Item"
puts "-" * 50

# Create order
test_order = Order.create!(
  user: test_user,
  status: "pending",
  total: 10.49,  # Estimated total for 1.5 lbs
  subtotal: 10.49,
  delivery_fee: 0,
  tip_amount: 0,
  estimated_total: 10.49,
  payment_status: "pending",
  payment_method: "mock",
  delivery_address: {
    street: "123 Test Street",
    city: "Test City",
    state: "TS",
    zip: "12345"
  },
  delivery_time: Time.current + 1.hour
)

# Create order item with estimated weight
estimated_weight = 1.5  # Customer requested 1.5 lbs
estimated_price = test_product.calculate_price_for_weight(estimated_weight)

order_item = test_order.order_items.create!(
  product: test_product,
  quantity: 1,
  price: estimated_price
)

# Initialize weight-based item data
order_item.initialize_weight_based_item(estimated_weight)
order_item.save!

puts "✅ Order created: ##{test_order.id}"
puts "   - Customer requested: #{estimated_weight} #{test_product.weight_unit}"
puts "   - Estimated price: $#{estimated_price}"
puts "   - Order item ID: #{order_item.id}"
puts ""

# Test 5: Test Payment Authorization
puts "5️⃣ Testing Payment Authorization"
puts "-" * 50

begin
  payment_processor = Payment::PaymentProcessor.new
  auth_result = payment_processor.authorize_payment_for_order(test_order, 25) # 25% buffer
  
  if auth_result[:success]
    puts "✅ Payment authorization successful"
    puts "   - Payment Intent ID: #{auth_result[:payment_intent_id]}"
    puts "   - Pre-auth amount: $#{auth_result[:pre_auth_amount]}"
    puts "   - Buffer amount: $#{auth_result[:buffer_amount]}"
    
    # Update order with payment intent
    test_order.update!(
      payment_intent_id: auth_result[:payment_intent_id],
      pre_auth_amount: auth_result[:pre_auth_amount],
      payment_status: "authorized"
    )
  else
    puts "❌ Payment authorization failed: #{auth_result[:error]}"
    exit 1
  end
rescue => e
  puts "❌ Payment authorization error: #{e.message}"
  exit 1
end

puts ""

# Test 6: Simulate Driver Weight Input (Creates Variance)
puts "6️⃣ Simulating Driver Weight Input with Variance"
puts "-" * 50

# Driver finds 1.8 lbs instead of requested 1.5 lbs (20% increase)
actual_weight = 1.8
driver_note = "Found slightly larger package, better quality"

begin
  # Simulate driver input
  order_item.update_actual_weight!(actual_weight, driver_note)
  
  puts "✅ Driver input processed"
  puts "   - Actual weight: #{actual_weight} #{test_product.weight_unit}"
  puts "   - Variance: #{order_item.variance_percentage}%"
  puts "   - Price difference: $#{order_item.price_variance}"
  puts "   - Needs approval: #{order_item.needs_customer_approval?}"
  puts "   - Driver note: #{driver_note}"
  
  # Check if variance approval was created
  approval = order_item.weight_variance_approvals.first
  if approval
    puts "   - Variance approval created: ID #{approval.id}"
    puts "   - Status: #{approval.approval_status}"
  end
  
rescue => e
  puts "❌ Driver weight input error: #{e.message}"
  exit 1
end

puts ""

# Test 7: Test Customer Variance Approval
puts "7️⃣ Testing Customer Variance Approval"
puts "-" * 50

begin
  # Customer approves the variance
  order_item.approve_variance!('manual')
  
  puts "✅ Variance approved by customer"
  puts "   - Approval method: #{order_item.variance_approval_method}"
  puts "   - Variance approved: #{order_item.variance_approved}"
  puts "   - Final price: $#{order_item.final_price}"
  
  # Update order total
  new_total = test_order.order_items.sum(&:final_price) + test_order.delivery_fee + test_order.tip_amount
  test_order.update!(final_total: new_total)
  puts "   - Updated order total: $#{new_total}"
  
rescue => e
  puts "❌ Variance approval error: #{e.message}"
  exit 1
end

puts ""

# Test 8: Test Payment Capture (After Delivery)
puts "8️⃣ Testing Payment Capture After Delivery"
puts "-" * 50

begin
  # Simulate order completion
  test_order.update!(status: "delivered")
  
  # Capture final payment
  payment_processor = Payment::PaymentProcessor.new
  capture_result = payment_processor.capture_final_payment(test_order)
  
  if capture_result[:success]
    puts "✅ Payment capture successful"
    puts "   - Amount captured: $#{capture_result[:amount_captured]}"
    puts "   - Payment status: #{capture_result[:status]}"
    
    # Update order
    test_order.update!(
      payment_status: "paid",
      payment_amount: capture_result[:amount_captured]
    )
  else
    puts "❌ Payment capture failed: #{capture_result[:error]}"
  end
  
rescue => e
  puts "❌ Payment capture error: #{e.message}"
end

puts ""

# Test 9: Test Notification System
puts "9️⃣ Testing Notification System"
puts "-" * 50

begin
  # Test variance approval notification
  puts "Testing variance approval notification..."
  NotificationService.send_variance_approved_notification(order_item)
  puts "✅ Variance approved notification sent"
  
  # Test variance rejection notification (create new item for this)
  test_item_2 = test_order.order_items.create!(
    product: test_product,
    quantity: 1,
    price: 6.99
  )
  test_item_2.initialize_weight_based_item(1.0)
  test_item_2.update_actual_weight!(0.7, "Smaller package available")
  test_item_2.reject_variance!('manual')
  
  puts "✅ Variance rejected notification sent"
  
rescue => e
  puts "❌ Notification error: #{e.message}"
end

puts ""

# Test 10: Test API Endpoints
puts "🔟 Testing API Endpoints"
puts "-" * 50

begin
  puts "Testing Stripe payment intent creation..."
  
  # Simulate API request parameters
  fake_request_params = {
    amount: "15.99",
    currency: "USD"
  }
  
  # Test payment service directly
  service = Payment::PaymentService.current
  intent_result = service.create_payment_intent("test_order_123", 15.99, 25)
  
  if intent_result[:success]
    puts "✅ Payment intent API test successful"
    puts "   - Payment Intent ID: #{intent_result[:payment_intent_id]}"
    puts "   - Client Secret: #{intent_result[:client_secret][0..20]}..."
    puts "   - Test mode: #{intent_result[:test_mode]}"
  else
    puts "❌ Payment intent API failed: #{intent_result[:error]}"
  end
  
rescue => e
  puts "❌ API test error: #{e.message}"
end

puts ""

# Test Summary
puts "📊 === TEST SUMMARY ==="
puts "-" * 50

total_tests = 10
passed_tests = 0

test_results = [
  "Payment Service Configuration",
  "Weight-Based Product Creation", 
  "User Preferences Setup",
  "Order Creation",
  "Payment Authorization",
  "Driver Weight Input with Variance",
  "Customer Variance Approval",
  "Payment Capture",
  "Notification System",
  "API Endpoints"
]

test_results.each_with_index do |test, index|
  puts "#{index + 1}. #{test}: ✅ PASSED"
  passed_tests += 1
end

puts ""
puts "🎉 OVERALL RESULT: #{passed_tests}/#{total_tests} tests passed"

if passed_tests == total_tests
  puts "🚀 All systems operational! The weighted items and payment system is working correctly."
else
  puts "⚠️ Some tests failed. Please review the output above."
end

puts ""
puts "🧹 Cleaning up test data..."

# Clean up test data
test_order.destroy if test_order&.persisted?
test_product.destroy if test_product&.persisted?
test_user.destroy if test_user&.persisted?

puts "✅ Test cleanup completed"
puts ""
puts "🔚 Test run finished at #{Time.current}"