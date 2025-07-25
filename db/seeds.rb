# Clear existing data
[DriverStat, Favorite, OrderItem, Order, Product, User].each(&:delete_all)

puts "Clearing existing data..."

# Create users (matching mockUsers from frontend)
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

puts "Created #{User.count} users..."

# Create products (matching mockItems from frontend)
products = [
  { name: 'Fresh Bananas', category: 'Fruits', price: 2.99, unit: 'lb', description: 'Sweet and ripe bananas', stock_quantity: 45 },
  { name: 'Organic Spinach', category: 'Vegetables', price: 3.49, unit: 'bunch', description: 'Fresh organic spinach leaves', stock_quantity: 8 },
  { name: 'Whole Milk', category: 'Dairy', price: 4.29, unit: 'gallon', description: 'Fresh whole milk', stock_quantity: 12 },
  { name: 'Sourdough Bread', category: 'Bakery', price: 5.99, unit: 'loaf', description: 'Artisan sourdough bread', stock_quantity: 6 },
  { name: 'Ground Beef', category: 'Meat', price: 8.99, unit: 'lb', description: '85% lean ground beef', stock_quantity: 20 },
  { name: 'Orange Juice', category: 'Beverages', price: 3.99, unit: 'bottle', description: 'Fresh squeezed orange juice', stock_quantity: 15 },
  { name: 'Red Apples', category: 'Fruits', price: 4.99, unit: 'bag', description: 'Crisp red apples', stock_quantity: 32 },
  { name: 'Carrots', category: 'Vegetables', price: 2.49, unit: 'lb', description: 'Fresh carrots', stock_quantity: 25 }
].map { |attrs| Product.create!(attrs.merge(in_stock: true)) }

puts "Created #{Product.count} products..."

# Create sample order (matching mockOrders from frontend)
order = Order.create!(
  user: customer,
  driver: driver,
  status: 'delivering',
  total: 10.27,
  delivery_address: {
    streetAddress: '123 Main St',
    city: 'Tamuning', 
    state: 'GU',
    zipCode: '96913'
  },
  eta: 900,
  estimated_payout: 15.50,
  created_at: 1.hour.ago
)

puts "Created sample order..."

# Create order items
OrderItem.create!(order: order, product: products[0], quantity: 2, price: 2.99, status: 'found', found_quantity: 2)
OrderItem.create!(order: order, product: products[2], quantity: 1, price: 4.29, status: 'found', found_quantity: 1)

puts "Created order items..."

# Create some favorites for the customer
Favorite.create!(user: customer, product: products[0]) # Bananas
Favorite.create!(user: customer, product: products[6]) # Red Apples

puts "Created favorites..."

# Create driver stats for the driver
DriverStat.create!(
  user: driver,
  date: Date.current,
  total_deliveries: 6,
  total_earnings: 127.50,
  average_rating: 4.8,
  total_ratings: 23
)

puts "Created driver stats..."

puts "✅ Seeded database with:"
puts "  - #{User.count} users (customer, driver, admin)"
puts "  - #{Product.count} products across #{Product.distinct.count(:category)} categories"
puts "  - #{Order.count} orders with #{OrderItem.count} items"
puts "  - #{Favorite.count} favorites"
puts "  - #{DriverStat.count} driver stat records"
puts ""
puts "🧪 Test credentials:"
puts "  Customer: customer@example.com / password"
puts "  Driver: driver@example.com / password"
puts "  Admin: admin@example.com / password"
