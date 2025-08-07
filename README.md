# Guahan Grocer Backend

Rails API backend for the Guahan Grocer grocery delivery app.

## 🚀 Quick Start

### Development Setup

```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start the server
rails server --port 3000
```

### Environment Variables

Create a `.env` file with:
```bash
DATABASE_URL=postgresql://...
REDIS_URL=redis://localhost:6379/0
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=your_secure_password
SECRET_KEY_BASE=your_secret_key
```

## 🚀 Deployment Instructions

### **Backend (Render) - Auto-deploy**
```bash
# 1. Make your changes
git add .
git commit -m "Backend changes"

# 2. Push to main branch
git push origin main

# ✅ Auto-deploys to Render
# Check: https://guahan-grocer-backend.onrender.com
# Monitor: https://guahan-grocer-backend.onrender.com/sidekiq
```

### **Deployment Environment**
- **Platform**: Render.com
- **Ruby Version**: 3.1.0
- **Database**: PostgreSQL (managed by Render)
- **Cache**: SolidCache (database-backed)
- **Background Jobs**: Sidekiq with Redis
- **File Storage**: AWS S3 (configured)

## 📱 Multi-Platform Frontend Support

This backend serves:
- **Web App**: https://guahan-grocer.netlify.app
- **iOS App**: TestFlight + App Store
- **Android App**: Google Play (when ready)

## 🔧 Key Features

- **JWT Authentication** with role-based access (customer, driver, admin)
- **RESTful API** for products, orders, users, favorites
- **Background Jobs** for delivery calculations and notifications
- **S3 Integration** for image uploads
- **CORS Configuration** for cross-origin requests
- **Sidekiq Web UI** for job monitoring

## 📡 API Endpoints

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration
- `GET /api/v1/auth/me` - Get current user
- `DELETE /api/v1/auth/logout` - User logout

### Products
- `GET /api/v1/products` - List products
- `GET /api/v1/products/featured` - Featured products
- `GET /api/v1/categories` - Product categories

### Orders
- `POST /api/v1/orders` - Create order
- `GET /api/v1/orders` - List user orders
- `PUT /api/v1/orders/:id/status` - Update order status

### Management
- `GET /sidekiq` - Job monitoring (HTTP Basic Auth required)

## 🛠 Development Commands

```bash
# Start development server
rails server

# Run background jobs
bundle exec sidekiq

# Database operations
rails db:migrate
rails db:seed
rails db:reset

# Testing
rails test

# Console
rails console
```

## 📦 Key Dependencies

- **Rails 8**: API framework
- **PostgreSQL**: Primary database
- **Redis**: Session store and Sidekiq
- **Sidekiq**: Background job processing
- **SolidCache**: Database-backed caching
- **JWT**: Authentication tokens
- **AWS SDK**: S3 file uploads
- **Rack-CORS**: Cross-origin support

## 🔄 Complete Stack Deployment

```bash
# Backend changes (auto-deploy):
git push origin main

# Frontend web changes:
cd ../guahan-grocer-frontend
npx expo export -p web
git add . && git commit -m "Frontend updates" && git push

# iOS app updates:
eas build --platform ios --profile production-ios
eas submit --platform ios --latest
```

## 🔐 Security Features

- **JWT Authentication** with 24-hour expiration
- **HTTP Basic Auth** for Sidekiq Web UI in production
- **CORS Configuration** for allowed origins
- **Input validation** and sanitization
- **SQL injection protection** via ActiveRecord
- **Password hashing** with bcrypt

## 📊 Monitoring

- **Sidekiq Web UI**: https://guahan-grocer-backend.onrender.com/sidekiq
- **Render Logs**: Available in Render dashboard
- **Health Check**: https://guahan-grocer-backend.onrender.com/up
# Force restart to apply Redis cache config
