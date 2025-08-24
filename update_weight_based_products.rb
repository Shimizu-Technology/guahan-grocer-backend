#!/usr/bin/env ruby
# Script to update products to be weight-based in production

puts "🔄 Updating weight-based products..."

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
not_found_count = 0

weight_based_products.each do |product_data|
  product = Product.find_by(name: product_data[:name])
  
  if product
    begin
      product.update!(
        weight_based: true,
        price_per_unit: product_data[:price_per_unit],
        weight_unit: product_data[:weight_unit],
        min_weight: product_data[:min_weight],
        max_weight: product_data[:max_weight]
      )
      
      puts "  ✅ Updated #{product.name} - $#{product_data[:price_per_unit]}/#{product_data[:weight_unit]}"
      updated_count += 1
    rescue => e
      puts "  ❌ Failed to update #{product_data[:name]}: #{e.message}"
    end
  else
    puts "  ⚠️  Product '#{product_data[:name]}' not found"
    not_found_count += 1
  end
end

puts "\n📊 Summary:"
puts "  ✅ Updated: #{updated_count} products"
puts "  ⚠️  Not found: #{not_found_count} products"

# Verify the updates
puts "\n🔍 Verification:"
weight_based_products.each do |product_data|
  product = Product.find_by(name: product_data[:name])
  if product
    puts "  #{product.name}: weight_based=#{product.weight_based?}, price_per_unit=$#{product.price_per_unit}"
  end
end

puts "\n✅ Weight-based products update complete!"
