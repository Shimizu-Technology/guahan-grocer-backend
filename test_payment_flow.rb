#!/usr/bin/env ruby

# Quick test for payment flow with proper payment intent tracking

puts "🔧 === Payment Flow Fix Test ==="
puts ""

ENV['USE_MOCK_PAYMENTS'] = 'true'

# Test proper payment intent flow
puts "Testing Payment Intent Storage and Capture..."
puts "-" * 50

begin
  # Find existing test data or create minimal test
  user = User.find_by(email: "test@example.com") || User.create!(
    name: "Test User", 
    email: "test@example.com", 
    password: "password",
    phone: "+16711234567",
    role: "customer"
  )
  
  order = Order.create!(
    user: user,
    status: "pending",
    total: 15.99,
    subtotal: 15.99,
    delivery_fee: 0,
    tip_amount: 0,
    payment_status: "pending",
    payment_method: "mock",
    delivery_address: { street: "123 Test St", city: "Test", state: "TS", zip: "12345" },
    delivery_time: Time.current + 1.hour
  )
  
  puts "✅ Test order created: ##{order.id}"
  
  # Test payment authorization with proper intent storage
  processor = Payment::PaymentProcessor.new
  auth_result = processor.authorize_payment_for_order(order, 25)
  
  if auth_result[:success]
    payment_intent_id = auth_result[:payment_intent][:id]
    puts "✅ Payment authorized successfully"
    puts "   - Payment Intent ID: #{payment_intent_id}"
    puts "   - Pre-auth Amount: $#{sprintf('%.2f', auth_result[:pre_auth_amount] || 0)}"
    puts "   - Authorized Amount: $#{sprintf('%.2f', auth_result[:payment_intent][:amount] || 0)}"
    
    # Store payment intent in order
    order.update!(
      payment_intent_id: payment_intent_id,
      pre_auth_amount: auth_result[:pre_auth_amount],
      payment_status: "authorized"
    )
    
    puts "✅ Payment intent stored in order"
    
    # Test payment capture
    order.update!(status: "delivered")
    capture_result = processor.capture_final_payment(order)
    
    if capture_result[:success]
      puts "✅ Payment captured successfully"
      puts "   - Amount Captured: $#{sprintf('%.2f', capture_result[:amount_captured] || 0)}"
      puts "   - Status: #{capture_result[:status]}"
    else
      puts "❌ Payment capture failed: #{capture_result[:error]}"
    end
    
  else
    puts "❌ Payment authorization failed: #{auth_result[:error]}"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
ensure
  # Cleanup
  order&.destroy
  puts ""
  puts "✅ Test completed"
end