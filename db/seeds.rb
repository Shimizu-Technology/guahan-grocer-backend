# Clear existing data
puts "🧹 Clearing existing data..."
[DriverStat, Favorite, OrderItem, Order, ProductCategory, Product, Category, Unit, Address, Vehicle, User].each(&:delete_all)

# Create users
puts "👥 Creating users..."

users_data = [
  {
  email: 'customer@example.com',
  name: 'John Customer', 
  role: 'customer',
  phone: '+1-671-555-0101',
  password: 'password',
  active: true
  },
  {
  email: 'driver@example.com',
  name: 'Jane Driver',
  role: 'driver', 
  phone: '+1-671-555-0102',
  password: 'password',
  active: true
  },
  {
  email: 'admin@example.com',
  name: 'Admin User',
  role: 'admin',
  phone: '+1-671-555-0103', 
  password: 'password',
  active: true
  }
]

users_created = 0
customer = nil
driver = nil
admin = nil

users_data.each do |user_attrs|
  begin
    user = User.create!(user_attrs)
    users_created += 1
    puts "  ✅ #{user.role.capitalize}: #{user.name} (#{user.email})"
    
    # Assign to variables for later use
    case user.role
    when 'customer'
      customer = user
    when 'driver'
      driver = user
    when 'admin'
      admin = user
    end
  rescue => e
    puts "  ❌ Failed to create #{user_attrs[:role]} #{user_attrs[:name]}: #{e.message}"
  end
end

# Only using main demo accounts for testing
all_customers = customer ? [customer] : []
all_drivers = driver ? [driver] : []

puts "Created #{users_created}/#{users_data.length} users (#{User.customer.count} customers, #{User.driver.count} drivers, #{User.admin.count} admins)"

# Create vehicle for driver
puts "🚗 Creating driver vehicle..."

if driver
  vehicle_data = {
    user: driver,
    make: 'Toyota',
    model: 'Camry',
    year: 2020,
    color: 'Silver',
    license_plate: 'GUM123',
    vehicle_type: 'sedan',
    verification_status: 'verified'
  }

  begin
    vehicle = Vehicle.create!(vehicle_data)
    puts "  ✅ Vehicle: #{vehicle.display_name} (#{vehicle.license_plate}) - #{vehicle.verification_status.capitalize}"
  rescue => e
    puts "  ❌ Failed to create vehicle: #{e.message}"
  end
else
  puts "  ⚠️  No driver found, skipping vehicle creation"
end

# Create categories
puts "📁 Creating categories..."

categories_data = [
  { name: 'Fruits', description: 'Fresh seasonal fruits and tropical varieties', icon: '🍎', color: '#EF4444' },
  { name: 'Vegetables', description: 'Fresh vegetables and leafy greens', icon: '🥬', color: '#10B981' },
  { name: 'Dairy', description: 'Milk, cheese, eggs and dairy products', icon: '🥛', color: '#3B82F6' },
  { name: 'Bakery', description: 'Fresh baked bread, pastries and baked goods', icon: '🍞', color: '#F59E0B' },
  { name: 'Meat', description: 'Fresh meat, poultry and seafood', icon: '🥩', color: '#DC2626' },
  { name: 'Pantry', description: 'Dry goods, oils, spices and cooking essentials', icon: '🥫', color: '#6B7280' },
  { name: 'Snacks', description: 'Chips, nuts, chocolate and snack foods', icon: '🍪', color: '#F97316' },
  { name: 'Personal Care', description: 'Health and beauty products', icon: '🧴', color: '#EC4899' },
  { name: 'Household', description: 'Cleaning supplies and household essentials', icon: '🧽', color: '#06B6D4' }
]

categories = {}
categories_created = 0
categories_data.each do |cat_data|
  begin
  category = Category.create!(cat_data)
  categories[category.name] = category
    categories_created += 1
  puts "  ✅ #{category.name} - #{category.description}"
  rescue => e
    puts "  ❌ Failed to create category '#{cat_data[:name]}': #{e.message}"
  end
end

puts "Created #{categories_created}/#{categories_data.length} categories"

# Create units
puts "📏 Creating units..."

units_data = [
  { name: 'each', symbol: 'ea' },
  { name: 'pound', symbol: 'lb' },
  { name: 'bag', symbol: 'bag' },
  { name: 'container', symbol: 'ct' },
  { name: 'gallon', symbol: 'gal' },
  { name: 'dozen', symbol: 'dz' },
  { name: 'package', symbol: 'pkg' },
  { name: 'loaf', symbol: 'loaf' },
  { name: 'pack', symbol: 'pk' },
  { name: 'bottle', symbol: 'btl' },
  { name: 'box', symbol: 'box' },
  { name: 'bunch', symbol: 'bunch' },
  { name: 'head', symbol: 'head' },
  { name: 'bar', symbol: 'bar' },
  { name: 'block', symbol: 'block' },
  { name: 'jar', symbol: 'jar' }
]

units = {}
units_created = 0
units_data.each do |unit_data|
  begin
  unit = Unit.create!(unit_data)
  units[unit.name] = unit
    units_created += 1
  puts "  ✅ #{unit.name} (#{unit.symbol})"
  rescue => e
    puts "  ❌ Failed to create unit '#{unit_data[:name]}': #{e.message}"
  end
end

puts "Created #{units_created}/#{units_data.length} units"

# Create comprehensive products
puts "🥗 Creating products..."

products_data = [
  # Vegetables
  { name: 'Cucumber', categories: ['Vegetables'], price: 4.79, unit: 'pound', description: 'Fresh crisp cucumbers, perfect for salads', track_inventory: false, featured: true, image_url: 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=300' },
  { name: 'Carrots', categories: ['Vegetables'], price: 1.19, unit: 'pound', description: 'Fresh orange carrots, great for cooking and snacking', track_inventory: false, featured: true, image_url: 'https://images.unsplash.com/photo-1582515073490-39981397c445?w=300' },
  { name: 'Baby Bokchoy', categories: ['Vegetables'], price: 2.19, unit: 'pound', description: 'Fresh baby bok choy, perfect for stir-fries', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=300' },
  { name: 'Yellow Onions', categories: ['Vegetables'], price: 0.89, unit: 'pound', description: 'Fresh yellow onions, cooking essential', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=300' },
  { name: 'Red Onions', categories: ['Vegetables'], price: 1.39, unit: 'pound', description: 'Fresh red onions, great for salads and grilling', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1624205779686-dbae5da698ad?w=300' },
  { name: 'White Onions', categories: ['Vegetables'], price: 1.49, unit: 'pound', description: 'Fresh white onions, mild flavor perfect for cooking', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1552432664-71d7c3bac909?w=300' },
  { name: 'Large Tomatos', categories: ['Vegetables'], price: 1.49, unit: 'pound', description: 'Fresh large tomatoes, perfect for slicing', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=300' },
  { name: 'Red Leaf Lettuce', categories: ['Vegetables'], price: 3.29, unit: 'pound', description: 'Fresh red leaf lettuce, perfect for salads', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=300' },
  
  # Fruits
  { name: 'California Mandarin Oranges', categories: ['Fruits'], price: 7.29, unit: 'bag', description: 'Sweet California mandarin oranges, easy to peel', track_inventory: false, featured: true, image_url: 'https://images.unsplash.com/photo-1582979512210-99b6a53386f9?w=300' },
  { name: 'Pineapple Cut Fruit Bowl', categories: ['Fruits'], price: 8.99, unit: 'each', description: 'Fresh cut pineapple in convenient bowl', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1589829481092-68b8ac3c24ce?w=300' },
  
  # Dairy
  { name: 'Knudsen Cottage Cheese 16oz', categories: ['Dairy'], price: 6.09, unit: 'container', description: 'Knudsen cottage cheese, high in protein', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1544047908-8d5d885f0b62?w=300' },
  { name: 'Daisy Sour Cream 24oz', categories: ['Dairy'], price: 6.59, unit: 'container', description: 'Daisy brand sour cream, 24oz container', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1586890271561-79ac2d50b8d1?w=300' },
  { name: 'California Sun Sour Cream 32oz', categories: ['Dairy'], price: 10.49, unit: 'container', description: 'California Sun brand sour cream, large 32oz size', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1586890271561-79ac2d50b8d1?w=300' },
  
  # Bakery
  { name: 'Stoneefire Naan Roasted Garlic 8.8oz', categories: ['Bakery'], price: 3.59, unit: 'package', description: 'Stonefire naan bread with roasted garlic', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1585478259715-876acc5be4eb?w=300' },
  
  # Meat  
  { name: 'Chicken Thighs Skinless/Boneless', categories: ['Meat'], price: 3.68, unit: 'pound', description: 'Fresh boneless skinless chicken thighs', track_inventory: false, featured: true, image_url: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=300' },
  
  # Personal Care
  { name: 'Kotex Tampons Click Super', categories: ['Personal Care'], price: 8.59, unit: 'box', description: 'Kotex Click tampons, super absorbency', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1584464491033-06628f3a6b7b?w=300' },
  { name: 'Kotex Tampons Click Super Plus', categories: ['Personal Care'], price: 8.59, unit: 'box', description: 'Kotex Click tampons, super plus absorbency', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1584464491033-06628f3a6b7b?w=300' },
  { name: 'Cetaphil Moisturizing Cream 16 oz', categories: ['Personal Care'], price: 26.95, unit: 'bottle', description: 'Cetaphil moisturizing cream for dry skin', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1556228453-efd6c1ff04f6?w=300' },
  
  # Pantry
  { name: 'Sapporo Ichiban Ramen Noodle Original', categories: ['Pantry'], price: 1.59, unit: 'package', description: 'Sapporo Ichiban original flavor ramen noodles', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300' },
  { name: 'Essential Pure Vegetable Oil 128oz', categories: ['Pantry'], price: 19.29, unit: 'bottle', description: 'Essential Everyday pure vegetable oil, 128oz', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300' },
  { name: 'Kikkoman Soy Sauce 1.8 Liters', categories: ['Pantry'], price: 6.19, unit: 'bottle', description: 'Kikkoman soy sauce, large 1.8L bottle', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1594708767771-a7502209ab40?w=300' },
  
  # Snacks
  { name: 'Rold Gold Pretzel Thins 10oz', categories: ['Snacks'], price: 6.79, unit: 'bag', description: 'Rold Gold pretzel thins, crispy and salty', track_inventory: false, featured: true, image_url: 'https://images.unsplash.com/photo-1599490659213-e2b9527bd087?w=300' },
  { name: 'Tostitos Dip Spinach Creamy 15oz', categories: ['Snacks'], price: 11.49, unit: 'jar', description: 'Tostitos creamy spinach dip, perfect for chips', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=300' },
  { name: 'Tostitos Chips Scoops Oven Baked 7oz', categories: ['Snacks'], price: 7.49, unit: 'bag', description: 'Tostitos Scoops oven baked tortilla chips', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300' },
  { name: 'Mini Chips Ahoy 8oz', categories: ['Snacks'], price: 4.39, unit: 'bag', description: 'Mini Chips Ahoy chocolate chip cookies', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=300' },
  { name: 'Nature Valley Crunchy Variety Pack 18oz', categories: ['Snacks'], price: 11.69, unit: 'box', description: 'Nature Valley crunchy granola bars variety pack', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300' },
  
  # Household
  { name: 'Arm & Hammer Detergent Liquid 2X Clean 105oz', categories: ['Household'], price: 18.99, unit: 'bottle', description: 'Arm & Hammer liquid laundry detergent, 2X concentrated', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=300' },
  { name: 'Charmin Ultra Soft Mega 6 rolls', categories: ['Household'], price: 12.99, unit: 'pack', description: 'Charmin Ultra Soft toilet paper, 6 mega rolls', track_inventory: false, image_url: 'https://images.unsplash.com/photo-1580450154955-0ba7ac532a6d?w=300' }
]

# All products are available since we're not tracking inventory
products_data.each do |product_data|
    product_data[:stock_quantity] = 0
    product_data[:in_stock] = true
  product_data[:featured] = product_data[:featured] || false
end

# Create products with proper associations
products = []
products_created = 0
featured_count = 0

products_data.each_with_index do |product_data, index|
  begin
  # Get the unit
  unit = units[product_data[:unit]]
  unless unit
    puts "  ❌ Warning: Unit '#{product_data[:unit]}' not found for product '#{product_data[:name]}'"
    next
  end
  
  # Create the product
  product = Product.create!(
    name: product_data[:name],
    price: product_data[:price],
    unit: unit,
    description: product_data[:description],
    stock_quantity: product_data[:stock_quantity] || 0,
    in_stock: product_data[:in_stock],
    image_url: product_data[:image_url],
      featured: product_data[:featured],
    track_inventory: product_data[:track_inventory] != false  # Default to true unless explicitly false
  )
  
  # Assign categories
    categories_assigned = 0
  product_data[:categories].each do |category_name|
    category = categories[category_name]
    if category
      product.categories << category
        categories_assigned += 1
    else
      puts "  ❌ Warning: Category '#{category_name}' not found for product '#{product.name}'"
    end
  end
  
    if categories_assigned > 0
      featured_indicator = product.featured? ? "⭐" : ""
      puts "  ✅ #{product.name} → #{product.categories.first.name} (#{unit.display_name}) #{featured_indicator}"
      products_created += 1
      featured_count += 1 if product.featured?
    else
      puts "  ❌ Failed to assign any categories to product '#{product.name}'"
      product.destroy
    end
    
    products << product if product.persisted?
  rescue => e
    puts "  ❌ Failed to create product '#{product_data[:name]}': #{e.message}"
  end
end

puts "Created #{products_created}/#{products_data.length} products across #{Category.count} categories"
puts "  ⭐ Featured Products: #{featured_count}"

puts ""
puts "🎉 Database seeded successfully!"
puts ""
puts "📊 Summary:"
puts "  👥 Users: #{User.count} (#{User.customer.count} customers, #{User.driver.count} drivers, #{User.admin.count} admins)"
puts "  📁 Categories: #{Category.count} (#{Category.pluck(:name).join(', ')})"
puts "  📏 Units: #{Unit.count} (#{Unit.pluck(:name).join(', ')})"
puts "  🥗 Products: #{Product.count} across #{Category.count} categories"
puts "     ♾️ All Available: #{Product.where(in_stock: true).count}"
puts "     ⭐ Featured Products: #{Product.featured.count}"
puts "     🔗 Product-Category Associations: #{ProductCategory.count}"
puts ""
# Create stores
puts "🏪 Creating stores..."

stores_data = [
  {
    name: "Micronesia Mall Pay‑Less",
    address: "1088 W Marine Corps Drive, Dededo, GU 96929",
    phone: "+1-671-637-7233", 
    latitude: 13.519410,
    longitude: 144.817290,
    active: true
  },
  {
    name: "Maite Pay‑Less",
    address: "751 Chalan Machaute, Maite, GU 96910",
    phone: "+1-671-477-7006",
    latitude: 13.4625,
    longitude: 144.7392,
    active: true
  },
  {
    name: "Dededo Pay‑Less",
    address: "214 West Marine Drive (Route 1), Dededo, GU 96929",
    phone: "+1-671-632-9419",
    latitude: 13.513611,
    longitude: 144.837222,
    active: true
  },
  {
    name: "Mangilao Pay‑Less",
    address: "121 Jesus Mariano Street, Mangilao, GU 96913",
    phone: "+1-671-735-0651",
    latitude: 13.437530,
    longitude: 144.794391,
    active: true
  },
  {
    name: "Oka Pay‑Less",
    address: "445 Gov Carlos G Camacho Rd, Oka, 96913, Guam",
    phone: "+1-671-646-9301",
    latitude: 13.498136,
    longitude: 144.776348,
    active: true
  },
  {
    name: "Sinajaña Pay‑Less",
    address: "128 Pale Kieran Hickey Drive, Sinajana, GU 96910",
    phone: "+1-671-477-7155",
    latitude: 13.46033913689201,
    longitude: 144.75762498431874,
    active: true
  },
  {
    name: "Sumay Pay‑Less",
    address: "137 Pedro LG Roberto Dr. (Rte 5), Santa Rita, GU 96915",
    phone: "+1-671-565-1330",
    latitude: 13.409793850565652,
    longitude: 144.67734577848432,
    active: true
  },
  {
    name: "Yigo Pay‑Less",
    address: "525 Chalan Ramon Haya, Yigo, GU 96929",
    phone: "+1-671-653-5410",
    latitude: 13.524350,
    longitude: 144.883100,
    active: true
  }
]

stores_created = 0
stores_data.each do |store_attrs|
  begin
    store = Store.find_or_create_by(name: store_attrs[:name]) do |new_store|
      new_store.assign_attributes(store_attrs)
    end
    
    if store.persisted?
      stores_created += 1
    else
      puts "  ❌ Failed to create #{store_attrs[:name]}: #{store.errors.full_messages.join(', ')}"
    end
  rescue => e
    puts "  ❌ Error creating #{store_attrs[:name]}: #{e.message}"
  end
end

puts "Created #{stores_created} stores across all of Guam"

# Create addresses for customers
puts "🏠 Creating customer addresses..."

# Addresses for main customer (John Customer)
john_addresses = [
  {
    user: customer,
    label: "Home",
    street_address: "125 Route 4",
    apartment_unit: "Apt 3B",
    city: "Tamuning",
    state: "GU",
    zip_code: "96913",
    is_default: true,
    latitude: 13.4877,
    longitude: 144.7789
  },
  {
    user: customer,
    label: "Work",
    street_address: "333 South Marine Corps Dr",
    city: "Tamuning",
    state: "GU", 
    zip_code: "96913",
    is_default: false,
    latitude: 13.4845,
    longitude: 144.7823
  }
]

# Create all addresses
all_address_data = john_addresses
all_address_data.each do |address_data|
  address = Address.create!(address_data)
  puts "  ✅ #{address.user.name}: #{address.display_label} - #{address.full_address}"
end

puts "Created #{Address.count} addresses for customers"

puts "🧪 Test with these credentials:"
puts "  👤 Customer: customer@example.com / password"
puts "  🚚 Driver: driver@example.com / password"  
puts "  👑 Admin: admin@example.com / password"
puts ""
puts "🏪 Browse categories: #{Category.pluck(:name).join(', ')}"
puts "📏 Available units: #{Unit.pluck(:name).join(', ')}"
puts "🏬 Available stores: #{Store.count} Pay-Less locations across Guam"
