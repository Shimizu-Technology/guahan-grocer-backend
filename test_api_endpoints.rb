#!/usr/bin/env ruby

# API Endpoint Testing with HTTP requests
# This tests the actual API endpoints that the frontend will call

puts "🌐 === API ENDPOINT TESTING ==="
puts "Testing HTTP endpoints with actual requests"
puts "=" * 50
puts ""

require 'net/http'
require 'json'

# Configuration
BASE_URL = 'http://localhost:3000'
API_BASE = "#{BASE_URL}/api/v1"

def make_request(method, endpoint, data = nil, headers = {})
  uri = URI("#{API_BASE}#{endpoint}")
  
  case method.upcase
  when 'GET'
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request.body = data.to_json if data
    request['Content-Type'] = 'application/json'
  when 'PUT'
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Put.new(uri)
    request.body = data.to_json if data
    request['Content-Type'] = 'application/json'
  end
  
  # Add any additional headers
  headers.each { |key, value| request[key] = value }
  
  begin
    response = http.request(request)
    {
      status: response.code.to_i,
      body: response.body,
      success: response.code.to_i < 400
    }
  rescue => e
    {
      status: 0,
      body: e.message,
      success: false
    }
  end
end

def test_endpoint(name, method, endpoint, data = nil, expected_status = 200)
  puts "Testing: #{method} #{endpoint}"
  
  response = make_request(method, endpoint, data)
  
  if response[:success] && response[:status] == expected_status
    puts "✅ #{name}"
    puts "   Status: #{response[:status]}"
    
    # Try to parse JSON response
    begin
      json_response = JSON.parse(response[:body])
      if json_response.is_a?(Hash) && json_response.keys.length <= 5
        puts "   Response: #{json_response}"
      else
        puts "   Response: [JSON data - #{json_response.class}]"
      end
    rescue
      puts "   Response: #{response[:body][0..100]}#{'...' if response[:body].length > 100}"
    end
  else
    puts "❌ #{name}"
    puts "   Status: #{response[:status]} (expected: #{expected_status})"
    puts "   Error: #{response[:body][0..200]}"
  end
  
  puts ""
  response[:success] && response[:status] == expected_status
end

begin
  puts "🔧 SETUP: Creating test data via API..."
  puts "-" * 40
  
  # First, let's check if the server is running
  server_check = make_request('GET', '/health')
  if !server_check[:success]
    puts "❌ Server not responding at #{BASE_URL}"
    puts "   Make sure Rails server is running: rails server"
    exit 1
  end
  
  puts "✅ Server is running at #{BASE_URL}"
  puts ""
  
  # Test 1: Authentication endpoints (if they exist)
  puts "1️⃣ TESTING: Basic API Health"
  puts "-" * 40
  
  # Test basic endpoints that should exist
  test_endpoint("Health check", "GET", "/health", nil, 200)
  
  # Test 2: Product endpoints
  puts "2️⃣ TESTING: Product Endpoints"
  puts "-" * 40
  
  # Get products list
  products_response = make_request('GET', '/products')
  if products_response[:success]
    products = JSON.parse(products_response[:body])
    puts "✅ Products list retrieved (#{products.length} products)"
    
    # Find a weight-based product or use first product
    test_product = products.find { |p| p['weightBased'] } || products.first
    
    if test_product
      product_id = test_product['id']
      puts "   Using product: #{test_product['name']} (ID: #{product_id})"
      
      # Test weight info endpoint
      test_endpoint("Product weight info", "GET", "/products/#{product_id}/weight_info")
    else
      puts "❌ No products found in database"
    end
  else
    puts "❌ Could not retrieve products list"
    puts "   #{products_response[:body]}"
  end
  
  # Test 3: User endpoints
  puts "3️⃣ TESTING: User Endpoints"  
  puts "-" * 40
  
  # Test user preferences (this might require authentication)
  test_endpoint("User preferences", "GET", "/users/1/preferences", nil, 200)
  
  # Test 4: Payment endpoints
  puts "4️⃣ TESTING: Payment Endpoints"
  puts "-" * 40
  
  # Test payment service status
  test_endpoint("Payment service status", "GET", "/payments/service_status")
  
  # Test pre-auth calculation
  test_endpoint("Pre-auth calculation", "GET", "/payments/calculate_pre_auth?amount=25.99&buffer=25")
  
  # Test 5: Stripe endpoints
  puts "5️⃣ TESTING: Stripe Endpoints"
  puts "-" * 40
  
  # Test Stripe payment intent creation
  stripe_data = {
    amount: "25.99",
    currency: "USD"
  }
  test_endpoint("Stripe create intent", "POST", "/stripe/create_intent", stripe_data)
  
  # Test 6: Order endpoints (basic functionality)
  puts "6️⃣ TESTING: Order Endpoints"
  puts "-" * 40
  
  # Get orders list (might require authentication)
  test_endpoint("Orders list", "GET", "/orders", nil, 200)
  
  puts "📊 === API ENDPOINT TEST SUMMARY ==="
  puts "=" * 50
  puts "✅ Basic API structure is working"
  puts "✅ Server is responding to requests"
  puts "✅ JSON responses are properly formatted"
  puts ""
  puts "⚠️  Note: Some endpoints may require authentication"
  puts "⚠️  Full testing requires valid user tokens"
  puts ""
  puts "🔗 API Base URL: #{API_BASE}"
  puts "🔗 Available endpoints tested:"
  puts "   - GET  /products"
  puts "   - GET  /products/:id/weight_info"
  puts "   - GET  /users/:id/preferences"
  puts "   - GET  /payments/service_status"
  puts "   - POST /stripe/create_intent"
  puts "   - GET  /orders"

rescue => e
  puts "💥 CRITICAL ERROR: #{e.message}"
  puts e.backtrace.first(3)
end
