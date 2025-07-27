# Clear existing data
puts "🧹 Clearing existing data..."
[DriverStat, Favorite, OrderItem, Order, ProductCategory, Product, Category, Unit, User].each(&:delete_all)

# Create users
puts "👥 Creating users..."

# Main demo users (matching login screen)
customer = User.create!(
  email: 'customer@example.com',
  name: 'John Customer', 
  role: 'customer',
  phone: '+1-671-555-0101',
  password: 'password',
  active: true
)

driver = User.create!(
  email: 'driver@example.com',
  name: 'Jane Driver',
  role: 'driver', 
  phone: '+1-671-555-0102',
  password: 'password',
  active: true
)

admin = User.create!(
  email: 'admin@example.com',
  name: 'Admin User',
  role: 'admin',
  phone: '+1-671-555-0103', 
  password: 'password',
  active: true
)

# Additional customers
customers = []
5.times do |i|
  customers << User.create!(
    email: "customer#{i+1}@example.com",
    name: "Customer #{i+1}",
    role: 'customer',
    phone: "+1-671-555-01#{10+i}",
    password: 'password',
    active: true
  )
end

# Additional drivers
drivers = []
3.times do |i|
  drivers << User.create!(
    email: "driver#{i+1}@example.com", 
    name: "Driver #{i+1}",
    role: 'driver',
    phone: "+1-671-555-02#{10+i}",
    password: 'password',
    active: true
  )
end

all_customers = [customer] + customers
all_drivers = [driver] + drivers

puts "Created #{User.count} users (#{User.customer.count} customers, #{User.driver.count} drivers, #{User.admin.count} admins)"

# Create categories
puts "📁 Creating categories..."

categories_data = [
  { name: 'Fruits', description: 'Fresh seasonal fruits and tropical varieties', icon: '🍎', color: '#EF4444' },
  { name: 'Vegetables', description: 'Fresh vegetables and leafy greens', icon: '🥬', color: '#10B981' },
  { name: 'Dairy', description: 'Milk, cheese, eggs and dairy products', icon: '🥛', color: '#3B82F6' },
  { name: 'Bakery', description: 'Fresh baked bread, pastries and baked goods', icon: '🍞', color: '#F59E0B' },
  { name: 'Meat', description: 'Fresh meat, poultry and seafood', icon: '🥩', color: '#DC2626' },
  { name: 'Beverages', description: 'Drinks, juices, coffee and tea', icon: '🥤', color: '#8B5CF6' },
  { name: 'Pantry', description: 'Dry goods, oils, spices and cooking essentials', icon: '🥫', color: '#6B7280' },
  { name: 'Snacks', description: 'Chips, nuts, chocolate and snack foods', icon: '🍪', color: '#F97316' }
]

categories = {}
categories_data.each do |cat_data|
  category = Category.create!(cat_data)
  categories[category.name] = category
  puts "  ✅ #{category.name} - #{category.description}"
end

puts "Created #{Category.count} categories"

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
  { name: 'block', symbol: 'block' }
]

units = {}
units_data.each do |unit_data|
  unit = Unit.create!(unit_data)
  units[unit.name] = unit
  puts "  ✅ #{unit.name} (#{unit.symbol})"
end

puts "Created #{Unit.count} units"

# Create comprehensive products
puts "🥗 Creating products..."

products_data = [
  # Fruits
  { name: 'Fresh Bananas', categories: ['Fruits'], price: 2.99, unit: 'pound', description: 'Sweet and ripe bananas from local farms', stock_quantity: 45, image_url: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=300', featured: true },
  { name: 'Red Apples', categories: ['Fruits'], price: 4.99, unit: 'bag', description: 'Crisp red apples, perfect for snacking', stock_quantity: 32, image_url: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=300' },
  { name: 'Naval Oranges', categories: ['Fruits'], price: 3.99, unit: 'bag', description: 'Juicy naval oranges packed with vitamin C', stock_quantity: 28, image_url: 'https://images.unsplash.com/photo-1582979512210-99b6a53386f9?w=300', featured: true },
  { name: 'Fresh Strawberries', categories: ['Fruits'], price: 5.99, unit: 'container', description: 'Sweet and juicy strawberries', stock_quantity: 15, image_url: 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=300', featured: true },
  { name: 'Ripe Avocados', categories: ['Fruits'], price: 2.49, unit: 'each', description: 'Perfect for toast or guacamole', stock_quantity: 22, image_url: 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=300' },
  { name: 'Fresh Pineapple', categories: ['Fruits'], price: 4.99, unit: 'each', description: 'Sweet tropical pineapple, locally grown', stock_quantity: 8, image_url: 'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?w=300' },
  
  # Vegetables  
  { name: 'Organic Spinach', categories: ['Vegetables'], price: 3.49, unit: 'bunch', description: 'Fresh organic spinach leaves', stock_quantity: 8, image_url: 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=300' },
  { name: 'Fresh Carrots', categories: ['Vegetables'], price: 2.49, unit: 'pound', description: 'Crunchy fresh carrots', stock_quantity: 25, image_url: 'https://images.unsplash.com/photo-1582515073490-39981397c445?w=300' },
  { name: 'Roma Tomatoes', categories: ['Vegetables'], price: 3.99, unit: 'pound', description: 'Perfect for sauces and salads', stock_quantity: 18, image_url: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=300' },
  { name: 'Fresh Broccoli', categories: ['Vegetables'], price: 2.99, unit: 'head', description: 'Nutritious fresh broccoli crowns', stock_quantity: 12, image_url: 'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?w=300' },
  { name: 'Bell Peppers', categories: ['Vegetables'], price: 4.99, unit: 'bag', description: 'Colorful mix of bell peppers', stock_quantity: 14, image_url: 'https://images.unsplash.com/photo-1593464936692-20a9eb2c6e2d?w=300' },
  { name: 'Fresh Cucumber', categories: ['Vegetables'], price: 1.99, unit: 'each', description: 'Crisp and refreshing cucumbers', stock_quantity: 20, image_url: 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=300' },
  
  # Dairy
  { name: 'Whole Milk', categories: ['Dairy'], price: 4.29, unit: 'gallon', description: 'Fresh whole milk from local dairies', stock_quantity: 12, image_url: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300', featured: true },
  { name: 'Large Eggs', categories: ['Dairy'], price: 3.99, unit: 'dozen', description: 'Farm fresh large eggs', stock_quantity: 24, image_url: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=300' },
  { name: 'Sharp Cheddar Cheese', categories: ['Dairy'], price: 5.99, unit: 'block', description: 'Aged sharp cheddar cheese', stock_quantity: 16, image_url: 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=300' },
  { name: 'Greek Yogurt', categories: ['Dairy'], price: 4.99, unit: 'container', description: 'Creamy Greek yogurt, high in protein', stock_quantity: 18, image_url: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=300' },
  { name: 'Unsalted Butter', categories: ['Dairy'], price: 4.49, unit: 'package', description: 'Premium unsalted butter', stock_quantity: 22, image_url: 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=300' },
  
  # Bakery
  { name: 'Sourdough Bread', categories: ['Bakery'], price: 5.99, unit: 'loaf', description: 'Artisan sourdough bread, baked fresh daily', stock_quantity: 6, image_url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300' },
  { name: 'Whole Wheat Bread', categories: ['Bakery'], price: 4.99, unit: 'loaf', description: 'Healthy whole wheat bread', stock_quantity: 8, image_url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300' },
  { name: 'Fresh Bagels', categories: ['Bakery'], price: 6.99, unit: 'pack', description: 'Assorted fresh bagels', stock_quantity: 12, image_url: 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=300' },
  { name: 'Croissants', categories: ['Bakery'], price: 7.99, unit: 'pack', description: 'Buttery French croissants', stock_quantity: 5, image_url: 'https://images.unsplash.com/photo-1555507036-ab794f4ade50?w=300' },
  
  # Meat  
  { name: 'Ground Beef', categories: ['Meat'], price: 8.99, unit: 'pound', description: '85% lean ground beef, locally sourced', stock_quantity: 20, image_url: 'https://images.unsplash.com/photo-1588168333986-5078d3ae3976?w=300' },
  { name: 'Chicken Breast', categories: ['Meat'], price: 9.99, unit: 'pound', description: 'Boneless skinless chicken breast', stock_quantity: 15, image_url: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=300' },
  { name: 'Salmon Fillet', categories: ['Meat'], price: 14.99, unit: 'pound', description: 'Fresh Atlantic salmon fillet', stock_quantity: 8, image_url: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=300' },
  { name: 'Pork Chops', categories: ['Meat'], price: 7.99, unit: 'pound', description: 'Thick cut pork chops', stock_quantity: 12, image_url: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=300' },
  
  # Beverages
  { name: 'Orange Juice', categories: ['Beverages'], price: 3.99, unit: 'bottle', description: 'Fresh squeezed orange juice', stock_quantity: 15, image_url: 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=300' },
  { name: 'Sparkling Water', categories: ['Beverages'], price: 4.99, unit: 'pack', description: '12-pack of sparkling water', stock_quantity: 25, image_url: 'https://images.unsplash.com/photo-1571741140674-8fc5ace84ad0?w=300' },
  { name: 'Fresh Coffee Beans', categories: ['Beverages', 'Pantry'], price: 12.99, unit: 'bag', description: 'Locally roasted coffee beans', stock_quantity: 18, image_url: 'https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=300' },
  { name: 'Green Tea', categories: ['Beverages'], price: 6.99, unit: 'box', description: 'Premium green tea bags', stock_quantity: 22, image_url: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=300' },
  
  # Pantry items
  { name: 'Extra Virgin Olive Oil', categories: ['Pantry'], price: 8.99, unit: 'bottle', description: 'Cold-pressed extra virgin olive oil', stock_quantity: 14, image_url: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300' },
  { name: 'Jasmine Rice', categories: ['Pantry'], price: 5.99, unit: 'bag', description: 'Premium jasmine rice, 5lb bag', stock_quantity: 20, image_url: 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=300' },
  { name: 'Sea Salt', categories: ['Pantry'], price: 3.99, unit: 'container', description: 'Pure sea salt for cooking', stock_quantity: 30, image_url: 'https://images.unsplash.com/photo-1472397264076-b5b5fce8cf6d?w=300' },
  { name: 'Black Pepper', categories: ['Pantry'], price: 4.99, unit: 'container', description: 'Freshly ground black pepper', stock_quantity: 25, image_url: 'https://images.unsplash.com/photo-1506629905607-d39ef65d0fa7?w=300' },
  
  # Snacks
  { name: 'Mixed Nuts', categories: ['Snacks'], price: 7.99, unit: 'bag', description: 'Premium mixed nuts', stock_quantity: 16, image_url: 'https://images.unsplash.com/photo-1566217796155-9d90b3c8d4d8?w=300' },
  { name: 'Potato Chips', categories: ['Snacks'], price: 3.99, unit: 'bag', description: 'Crispy potato chips', stock_quantity: 24, image_url: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300' },
  { name: 'Dark Chocolate', categories: ['Snacks'], price: 5.99, unit: 'bar', description: '70% dark chocolate bar', stock_quantity: 12, image_url: 'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=300' }
]

# Some items should be out of stock for testing
out_of_stock_indices = [1, 8, 15, 22] # Make some items out of stock
products_data.each_with_index do |product_data, index|
  if out_of_stock_indices.include?(index)
    product_data[:stock_quantity] = 0
    product_data[:in_stock] = false
  else
    product_data[:in_stock] = true
  end
end

# Create products with proper associations
products = []
products_data.each_with_index do |product_data, index|
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
    stock_quantity: product_data[:stock_quantity],
    in_stock: product_data[:in_stock],
    image_url: product_data[:image_url],
    featured: product_data[:featured] || false
  )
  
  # Assign categories
  product_data[:categories].each do |category_name|
    category = categories[category_name]
    if category
      product.categories << category
      puts "  ✅ #{product.name} → #{category.name} (#{unit.display_name})"
    else
      puts "  ❌ Warning: Category '#{category_name}' not found for product '#{product.name}'"
    end
  end
  
  products << product
end

puts "Created #{Product.count} products across #{Category.count} categories"

# Create orders in different states
puts "📦 Creating orders..."

# Order 1: Pending order (unassigned)
order1 = Order.create!(
  user: all_customers[0],
  status: 'pending',
  total: 23.47,
  delivery_address: {
    streetAddress: '123 Marine Corps Dr',
    city: 'Tamuning',
    state: 'GU', 
    zipCode: '96913'
  },
  estimated_payout: 18.50,
  created_at: 30.minutes.ago
)

OrderItem.create!(order: order1, product: products[0], quantity: 3, price: 2.99) # Bananas
OrderItem.create!(order: order1, product: products[12], quantity: 1, price: 4.29) # Milk
OrderItem.create!(order: order1, product: products[17], quantity: 2, price: 5.99) # Bread

# Order 2: Shopping (assigned to driver)
order2 = Order.create!(
  user: all_customers[1],
  driver: all_drivers[0],
  status: 'shopping',
  total: 31.94,
  delivery_address: {
    streetAddress: '456 Pale San Vitores Rd',
    city: 'Tumon',
    state: 'GU',
    zipCode: '96913'
  },
  estimated_payout: 22.75,
  created_at: 2.hours.ago
)

OrderItem.create!(order: order2, product: products[2], quantity: 2, price: 3.99, status: 'found', found_quantity: 2) # Oranges
OrderItem.create!(order: order2, product: products[13], quantity: 1, price: 3.99, status: 'found', found_quantity: 1) # Eggs
OrderItem.create!(order: order2, product: products[20], quantity: 1, price: 8.99, status: 'pending') # Ground Beef
OrderItem.create!(order: order2, product: products[6], quantity: 1, price: 3.49, status: 'unavailable') # Spinach

# Order 3: Delivering  
order3 = Order.create!(
  user: all_customers[2],
  driver: all_drivers[1],
  status: 'delivering',
  total: 18.97,
  delivery_address: {
    streetAddress: '789 South Marine Corps Dr',
    city: 'Tamuning', 
    state: 'GU',
    zipCode: '96913'
  },
  estimated_payout: 16.25,
  created_at: 4.hours.ago
)

OrderItem.create!(order: order3, product: products[4], quantity: 2, price: 2.49, status: 'found', found_quantity: 2) # Avocados
OrderItem.create!(order: order3, product: products[14], quantity: 1, price: 5.99, status: 'found', found_quantity: 1) # Cheddar
OrderItem.create!(order: order3, product: products[25], quantity: 1, price: 3.99, status: 'found', found_quantity: 1) # Orange Juice

# Order 4: Delivered
order4 = Order.create!(
  user: all_customers[3],
  driver: all_drivers[0],
  status: 'delivered',
  total: 42.93,
  delivery_address: {
    streetAddress: '321 Harmon Loop Rd',
    city: 'Dededo',
    state: 'GU',
    zipCode: '96929'
  },
  estimated_payout: 28.50,
  created_at: 1.day.ago
)

OrderItem.create!(order: order4, product: products[21], quantity: 2, price: 9.99, status: 'found', found_quantity: 2) # Chicken
OrderItem.create!(order: order4, product: products[5], quantity: 1, price: 4.99, status: 'found', found_quantity: 1) # Pineapple  
OrderItem.create!(order: order4, product: products[29], quantity: 1, price: 5.99, status: 'found', found_quantity: 1) # Rice

# Order 5: Available for pickup (for driver testing)
order5 = Order.create!(
  user: all_customers[4],
  status: 'pending',
  total: 27.95,
  delivery_address: {
    streetAddress: '555 Route 8',
    city: 'Mangilao',
    state: 'GU',
    zipCode: '96923'
  },
  estimated_payout: 19.75,
  created_at: 15.minutes.ago
)

OrderItem.create!(order: order5, product: products[3], quantity: 2, price: 5.99) # Strawberries
OrderItem.create!(order: order5, product: products[15], quantity: 1, price: 4.99) # Yogurt
OrderItem.create!(order: order5, product: products[26], quantity: 1, price: 4.99) # Sparkling Water

puts "Created #{Order.count} orders with #{OrderItem.count} total items"

# Create favorites
puts "❤️ Creating favorites..."

# Customer favorites
favorites_data = [
  [customer, products[0]], # Bananas
  [customer, products[6]], # Red Apples  
  [customer, products[12]], # Milk
  [customer, products[20]], # Ground Beef
  [all_customers[0], products[3]], # Strawberries
  [all_customers[0], products[27]], # Coffee
  [all_customers[1], products[5]], # Pineapple
  [all_customers[1], products[14]], # Cheddar
  [all_customers[2], products[26]], # Sparkling Water
  [all_customers[2], products[32]], # Dark Chocolate
]

favorites_data.each do |user, product|
  Favorite.create!(user: user, product: product)
end

puts "Created #{Favorite.count} favorites"

# Create driver stats
puts "📊 Creating driver stats..."

# Stats for main driver over the past week
7.times do |days_ago|
  date = days_ago.days.ago.to_date
  deliveries = case days_ago
  when 0 then 3  # Today
  when 1 then 8  # Yesterday  
  when 2 then 6  # 2 days ago
  else rand(4..9) # Random for older days
  end
  
  earnings = deliveries * (15..25).to_a.sample
  
  DriverStat.create!(
    user: driver,
    date: date,
    total_deliveries: deliveries,
    total_earnings: earnings,
    average_rating: [4.6, 4.7, 4.8, 4.9].sample,
    total_ratings: deliveries * rand(1..3)
  )
end

# Stats for other drivers
all_drivers[1..-1].each do |other_driver|
  3.times do |days_ago|
    date = days_ago.days.ago.to_date
    deliveries = rand(3..7)
    earnings = deliveries * (12..22).to_a.sample
    
    DriverStat.create!(
      user: other_driver,
      date: date,
      total_deliveries: deliveries,
      total_earnings: earnings,
      average_rating: [4.4, 4.5, 4.6, 4.7, 4.8].sample,
      total_ratings: deliveries * rand(1..2)
    )
  end
end

puts "Created #{DriverStat.count} driver stat records"

puts ""
puts "🎉 Database seeded successfully!"
puts ""
puts "📊 Summary:"
puts "  👥 Users: #{User.count} (#{User.customer.count} customers, #{User.driver.count} drivers, #{User.admin.count} admins)"
puts "  📁 Categories: #{Category.count} (#{Category.pluck(:name).join(', ')})"
puts "  📏 Units: #{Unit.count} (#{Unit.pluck(:name).join(', ')})"
puts "  🥗 Products: #{Product.count} across #{Category.count} categories"
puts "     📦 In Stock: #{Product.where(in_stock: true).count}"
puts "     ❌ Out of Stock: #{Product.where(in_stock: false).count}"
puts "     🔗 Product-Category Associations: #{ProductCategory.count}"
puts "  📦 Orders: #{Order.count} orders with #{OrderItem.count} total items"
puts "     🆕 Pending: #{Order.where(status: 'pending').count}"
puts "     🛒 Shopping: #{Order.where(status: 'shopping').count}" 
puts "     🚚 Delivering: #{Order.where(status: 'delivering').count}"
puts "     ✅ Delivered: #{Order.where(status: 'delivered').count}"
puts "  ❤️ Favorites: #{Favorite.count}"
puts "  📊 Driver Stats: #{DriverStat.count} records"
puts ""
puts "🧪 Test with these credentials:"
puts "  👤 Customer: customer@example.com / password"
puts "  🚚 Driver: driver@example.com / password"  
puts "  👑 Admin: admin@example.com / password"
puts ""
puts "🏪 Browse categories: #{Category.pluck(:name).join(', ')}"
puts "📏 Available units: #{Unit.pluck(:name).join(', ')}"
