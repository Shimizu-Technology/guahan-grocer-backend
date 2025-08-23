#!/usr/bin/env ruby

# Comprehensive API Test Suite for Weighted Items & Payment System
# This tests all new functionality end-to-end

puts "🧪 === COMPREHENSIVE API TEST SUITE ==="
puts "Testing all weighted items and payment functionality"
puts "=" * 60
puts ""

# Setup test environment
ENV['USE_MOCK_PAYMENTS'] = 'true'
ENV['STRIPE_TEST_MODE'] = 'true'

# Test counters
total_tests = 0
passed_tests = 0
failed_tests = []

def test_result(test_name, success, details = nil)
  global_total = $total_tests ||= 0
  global_passed = $passed_tests ||= 0
  global_failed = $failed_tests ||= []
  
  $total_tests = global_total + 1
  
  if success
    puts "✅ #{test_name}"
    puts "   #{details}" if details
    $passed_tests = global_passed + 1
  else
    puts "❌ #{test_name}"
    puts "   ERROR: #{details}" if details
    $failed_tests << test_name
  end
  puts ""
end

begin
  puts "🔧 SETUP: Creating test data..."
  puts "-" * 40
  
  # Clean up any existing test data
  User.where(email: ['test_customer@example.com', 'test_driver@example.com']).destroy_all
  Product.where(name: 'Test Ground Beef').destroy_all
  
  # Create test users
  test_customer = User.create!(
    name: "Test Customer",
    email: "test_customer@example.com",
    password: "password123",
    phone: "+16711234567",
    role: "customer",
    auto_approve_variances: false,
    max_auto_variance_percentage: 15,
    variance_notification_method: "push"
  )
  
  test_driver = User.create!(
    name: "Test Driver", 
    email: "test_driver@example.com",
    password: "password123",
    phone: "+16711234568",
    role: "driver"
  )
  
  # Create weight-based product
  test_product = Product.create!(
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
  
  puts "✅ Test data created successfully"
  puts "   - Customer: #{test_customer.email}"
  puts "   - Driver: #{test_driver.email}"
  puts "   - Product: #{test_product.name} (#{test_product.weight_based? ? 'weight-based' : 'fixed-price'})"
  puts ""
  
  # TEST 1: Product Weight Info API
  puts "1️⃣ TESTING: Product Weight Info API"
  puts "-" * 40
  
  begin
    # Test the weight info endpoint
    weight_info = {
      weight_based: test_product.weight_based?,
      price_per_unit: test_product.price_per_unit,
      weight_unit: test_product.weight_unit,
      min_weight: test_product.min_weight,
      max_weight: test_product.max_weight,
      weight_range: test_product.weight_range_text,
      price_info: test_product.display_price_info
    }
    
    test_result("Product weight info generation", true, 
      "Price: $#{weight_info[:price_per_unit]}/#{weight_info[:weight_unit]}, Range: #{weight_info[:weight_range]}")
    
    # Test price calculation for different weights
    test_weights = [0.5, 1.0, 1.5, 2.0, 2.5]
    test_weights.each do |weight|
      calculated_price = test_product.calculate_price_for_weight(weight)
      expected_price = weight * test_product.price_per_unit
      
      test_result("Price calculation for #{weight}lb", 
        (calculated_price - expected_price).abs < 0.01,
        "$#{calculated_price} (expected: $#{expected_price})")
    end
    
  rescue => e
    test_result("Product weight info API", false, e.message)
  end
  
  # TEST 2: Order Creation with Payment Authorization
  puts "2️⃣ TESTING: Order Creation with Payment Authorization"
  puts "-" * 40
  
  begin
    # Create order with weight-based item
    test_order = Order.create!(
      user: test_customer,
      status: "pending",
      total: 10.49,
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
    
    test_result("Order creation", true, "Order ##{test_order.id} created")
    
    # Create order item with estimated weight
    estimated_weight = 1.5
    estimated_price = test_product.calculate_price_for_weight(estimated_weight)
    
    order_item = test_order.order_items.create!(
      product: test_product,
      quantity: 1,
      price: estimated_price
    )
    
    # Initialize weight-based item
    order_item.initialize_weight_based_item(estimated_weight)
    order_item.save!
    
    test_result("Weight-based order item creation", true,
      "Item: #{estimated_weight}lb @ $#{estimated_price}")
    
    # Test payment authorization
    processor = Payment::PaymentProcessor.new
    auth_result = processor.authorize_payment_for_order(test_order, 25)
    
    if auth_result[:success]
      payment_intent_id = auth_result[:payment_intent][:id]
      test_order.update!(
        payment_intent_id: payment_intent_id,
        pre_auth_amount: auth_result[:pre_auth_amount],
        payment_status: "authorized"
      )
      
      test_result("Payment authorization", true,
        "Intent: #{payment_intent_id}, Amount: $#{auth_result[:pre_auth_amount]}")
    else
      test_result("Payment authorization", false, auth_result[:error])
    end
    
  rescue => e
    test_result("Order creation with payment", false, e.message)
  end
  
  # TEST 3: Driver Weight Input & Variance Calculation
  puts "3️⃣ TESTING: Driver Weight Input & Variance Calculation"
  puts "-" * 40
  
  begin
    # Test weight update with variance
    actual_weight = 1.8  # 20% increase from 1.5lb
    driver_note = "Found larger package, better quality"
    
    # Simulate driver weight input
    order_item.update_actual_weight!(actual_weight, driver_note)
    
    variance_percentage = order_item.variance_percentage
    needs_approval = order_item.needs_customer_approval?
    
    test_result("Driver weight input", true,
      "Actual: #{actual_weight}lb, Variance: #{variance_percentage}%, Needs approval: #{needs_approval}")
    
    # Test variance approval creation
    approval = order_item.weight_variance_approvals.first
    if approval
      test_result("Variance approval creation", true,
        "Approval ID: #{approval.id}, Status: #{approval.approval_status}")
    else
      test_result("Variance approval creation", false, "No approval created")
    end
    
    # Test auto-approval logic
    test_customer.update!(auto_approve_variances: true, max_auto_variance_percentage: 25)
    
    # Create another item to test auto-approval
    small_variance_item = test_order.order_items.create!(
      product: test_product,
      quantity: 1,
      price: 6.99
    )
    small_variance_item.initialize_weight_based_item(1.0)
    small_variance_item.update_actual_weight!(1.1, "Slightly heavier")  # 10% variance
    
    test_result("Auto-approval logic", small_variance_item.variance_approved?,
      "10% variance auto-approved: #{small_variance_item.variance_approved?}")
    
  rescue => e
    test_result("Driver weight input", false, e.message)
  end
  
  # TEST 4: Customer Variance Approval Process
  puts "4️⃣ TESTING: Customer Variance Approval Process"
  puts "-" * 40
  
  begin
    # Test manual approval
    order_item.approve_variance!('manual')
    
    test_result("Customer variance approval", order_item.variance_approved?,
      "Approval method: #{order_item.variance_approval_method}")
    
    # Test rejection scenario
    rejection_item = test_order.order_items.create!(
      product: test_product,
      quantity: 1,
      price: 6.99
    )
    rejection_item.initialize_weight_based_item(1.0)
    rejection_item.update_actual_weight!(0.6, "Only smaller package available")
    rejection_item.reject_variance!('manual')
    
    test_result("Customer variance rejection", !rejection_item.variance_approved?,
      "Rejection recorded: #{!rejection_item.variance_approved?}")
    
  rescue => e
    test_result("Customer variance approval", false, e.message)
  end
  
  # TEST 5: Payment Capture & Reconciliation
  puts "5️⃣ TESTING: Payment Capture & Reconciliation"
  puts "-" * 40
  
  begin
    # Calculate final total with approved variances
    final_total = test_order.order_items.sum(&:final_price)
    test_order.update!(final_total: final_total, status: "delivered")
    
    test_result("Final total calculation", true,
      "Final total: $#{final_total}")
    
    # Test payment capture
    capture_result = processor.capture_final_payment(test_order)
    
    if capture_result[:success]
      test_order.update!(payment_status: "paid")
      test_result("Payment capture", true,
        "Amount captured: $#{capture_result[:amount_captured] || final_total}")
    else
      test_result("Payment capture", false, capture_result[:error])
    end
    
  rescue => e
    test_result("Payment capture", false, e.message)
  end
  
  # TEST 6: User Preferences API
  puts "6️⃣ TESTING: User Preferences API"
  puts "-" * 40
  
  begin
    # Test preference updates
    original_auto_approve = test_customer.auto_approve_variances
    test_customer.update!(
      auto_approve_variances: true,
      max_auto_variance_percentage: 20,
      auto_approve_overages_only: true
    )
    
    test_result("User preference update", true,
      "Auto-approve: #{test_customer.auto_approve_variances}, Max: #{test_customer.max_auto_variance_percentage}%")
    
    # Test preference validation
    invalid_update = test_customer.update(max_auto_variance_percentage: 50)  # Should be limited
    
    test_result("Preference validation", !invalid_update,
      "Invalid percentage rejected: #{!invalid_update}")
    
  rescue => e
    test_result("User preferences", false, e.message)
  end
  
  # TEST 7: Notification System
  puts "7️⃣ TESTING: Notification System"
  puts "-" * 40
  
  begin
    # Test notification service calls
    NotificationService.send_variance_approval_notification(order_item)
    test_result("Variance approval notification", true, "Notification sent successfully")
    
    NotificationService.send_variance_approved_notification(order_item)
    test_result("Variance approved notification", true, "Notification sent successfully")
    
    NotificationService.send_variance_rejected_notification(rejection_item)
    test_result("Variance rejected notification", true, "Notification sent successfully")
    
  rescue => e
    test_result("Notification system", false, e.message)
  end
  
  # TEST 8: Payment Service Status & Configuration
  puts "8️⃣ TESTING: Payment Service Status & Configuration"
  puts "-" * 40
  
  begin
    service_status = Payment::PaymentService.status
    test_result("Payment service status", true,
      "Service: #{service_status[:service_name]}")
    
    # Test service switching
    using_mock = Payment::PaymentService.using_mock?
    test_result("Mock service detection", using_mock,
      "Using mock payments: #{using_mock}")
    
    # Test Stripe service (in test mode)
    stripe_service = Payment::StripePaymentService.new
    stripe_status = stripe_service.status
    test_result("Stripe service status", true,
      "Stripe status: #{stripe_status[:status]}")
    
  rescue => e
    test_result("Payment service configuration", false, e.message)
  end
  
  # TEST 9: Edge Cases & Error Handling
  puts "9️⃣ TESTING: Edge Cases & Error Handling"
  puts "-" * 40
  
  begin
    # Test invalid weight input
    begin
      order_item.update_actual_weight!(-1.0, "Invalid weight")
      test_result("Invalid weight handling", false, "Negative weight accepted")
    rescue => e
      test_result("Invalid weight handling", true, "Negative weight rejected")
    end
    
    # Test weight outside product range
    begin
      order_item.update_actual_weight!(5.0, "Weight exceeds max")  # Max is 3.0
      test_result("Weight range validation", false, "Excessive weight accepted")
    rescue => e
      test_result("Weight range validation", true, "Excessive weight rejected")
    end
    
    # Test payment with invalid order
    begin
      invalid_order = Order.new(id: 99999)
      processor.capture_final_payment(invalid_order)
      test_result("Invalid order payment", false, "Invalid order processed")
    rescue => e
      test_result("Invalid order payment", true, "Invalid order rejected")
    end
    
  rescue => e
    test_result("Edge case handling", false, e.message)
  end
  
  # TEST 10: Performance & Database Queries
  puts "🔟 TESTING: Performance & Database Queries"
  puts "-" * 40
  
  begin
    # Test bulk operations
    start_time = Time.current
    
    # Create multiple orders to test performance
    5.times do |i|
      bulk_order = Order.create!(
        user: test_customer,
        status: "pending",
        total: 15.99,
        subtotal: 15.99,
        delivery_fee: 0,
        tip_amount: 0,
        payment_status: "pending",
        payment_method: "mock",
        delivery_address: { street: "#{i} Bulk St", city: "Test", state: "TS", zip: "12345" },
        delivery_time: Time.current + 1.hour
      )
      
      bulk_item = bulk_order.order_items.create!(
        product: test_product,
        quantity: 1,
        price: 10.49
      )
      bulk_item.initialize_weight_based_item(1.5)
    end
    
    end_time = Time.current
    processing_time = end_time - start_time
    
    test_result("Bulk order creation", processing_time < 5.0,
      "Created 5 orders in #{processing_time.round(2)}s")
    
    # Test query performance
    start_time = Time.current
    orders_with_variances = Order.joins(:order_items)
                                 .where(order_items: { weight_based: true })
                                 .includes(:order_items, :user)
                                 .limit(10)
    orders_with_variances.to_a  # Force query execution
    end_time = Time.current
    query_time = end_time - start_time
    
    test_result("Complex query performance", query_time < 1.0,
      "Query executed in #{query_time.round(3)}s")
    
  rescue => e
    test_result("Performance testing", false, e.message)
  end

rescue => e
  puts "💥 CRITICAL ERROR: #{e.message}"
  puts e.backtrace.first(5)
ensure
  # Cleanup test data
  puts ""
  puts "🧹 CLEANUP: Removing test data..."
  begin
    Order.where(user: [test_customer, test_driver]).destroy_all if defined?(test_customer) && defined?(test_driver)
    User.where(email: ['test_customer@example.com', 'test_driver@example.com']).destroy_all
    Product.where(name: 'Test Ground Beef').destroy_all
    puts "✅ Cleanup completed"
  rescue => e
    puts "❌ Cleanup error: #{e.message}"
  end
end

# Final Results
puts ""
puts "📊 === TEST RESULTS SUMMARY ==="
puts "=" * 60

total = $total_tests || 0
passed = $passed_tests || 0
failed_count = ($failed_tests || []).length

puts "Total Tests: #{total}"
puts "Passed: #{passed} ✅"
puts "Failed: #{failed_count} ❌"

if failed_count > 0
  puts ""
  puts "Failed Tests:"
  ($failed_tests || []).each_with_index do |test, i|
    puts "  #{i + 1}. #{test}"
  end
end

success_rate = total > 0 ? (passed.to_f / total * 100).round(1) : 0
puts ""
puts "Success Rate: #{success_rate}%"

if success_rate >= 90
  puts "🎉 EXCELLENT! System is working well."
elsif success_rate >= 75
  puts "✅ GOOD! Minor issues to address."
elsif success_rate >= 50
  puts "⚠️ NEEDS WORK! Several issues found."
else
  puts "🚨 CRITICAL! Major issues detected."
end

puts ""
puts "🔚 Test completed at #{Time.current}"
