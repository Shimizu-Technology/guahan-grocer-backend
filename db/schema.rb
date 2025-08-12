# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_12_041700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "label", limit: 50
    t.string "street_address", limit: 255, null: false
    t.string "apartment_unit", limit: 50
    t.string "city", limit: 100, null: false
    t.string "state", limit: 10, null: false
    t.string "zip_code", limit: 20, null: false
    t.boolean "is_default", default: false, null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["latitude", "longitude"], name: "index_addresses_on_latitude_and_longitude"
    t.index ["user_id", "is_default"], name: "index_addresses_on_user_id_and_is_default"
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon"
    t.string "color"
    t.index ["active", "name"], name: "index_categories_on_active_and_name"
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "driver_stats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "total_deliveries", default: 0
    t.decimal "total_earnings", precision: 8, scale: 2, default: "0.0"
    t.decimal "average_rating", precision: 3, scale: 2
    t.integer "total_ratings", default: 0
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tips", precision: 8, scale: 2, default: "0.0"
    t.decimal "base_pay", precision: 8, scale: 2, default: "0.0"
    t.decimal "bonuses", precision: 8, scale: 2, default: "0.0"
    t.decimal "expenses", precision: 8, scale: 2, default: "0.0"
    t.decimal "hours_online", precision: 5, scale: 2, default: "0.0"
    t.integer "orders_offered", default: 0
    t.integer "orders_accepted", default: 0
    t.datetime "went_online_at"
    t.datetime "went_offline_at"
    t.index ["user_id", "date"], name: "index_driver_stats_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_driver_stats_on_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_favorites_on_product_id"
    t.index ["user_id", "product_id"], name: "index_favorites_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "event_type", null: false
    t.bigint "user_id"
    t.jsonb "data", default: {}
    t.datetime "occurred_at", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type", "occurred_at"], name: "index_order_events_on_event_type_and_occurred_at"
    t.index ["order_id", "occurred_at"], name: "index_order_events_on_order_id_and_occurred_at"
    t.index ["order_id"], name: "index_order_events_on_order_id"
    t.index ["user_id", "occurred_at"], name: "index_order_events_on_user_id_and_occurred_at", where: "(user_id IS NOT NULL)"
    t.index ["user_id"], name: "index_order_events_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.decimal "price", precision: 8, scale: 2
    t.integer "status", default: 0
    t.integer "found_quantity"
    t.text "notes"
    t.bigint "substitute_product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "status"], name: "index_order_items_on_order_id_and_status"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id", "order_id"], name: "index_order_items_on_product_id_and_order_id", comment: "For product-order joins"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["substitute_product_id"], name: "index_order_items_on_substitute_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "driver_id"
    t.integer "status"
    t.decimal "total", precision: 8, scale: 2
    t.jsonb "delivery_address"
    t.integer "eta"
    t.decimal "estimated_payout", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tip_amount", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "tip_percentage", precision: 5, scale: 2, default: "0.0", null: false
    t.text "delivery_instructions"
    t.string "delivery_time"
    t.decimal "subtotal", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "delivery_fee", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "actual_delivery_fee", precision: 8, scale: 2
    t.bigint "assigned_store_id"
    t.decimal "store_distance_miles", precision: 8, scale: 2
    t.string "store_name"
    t.integer "estimated_delivery_minutes"
    t.string "receipt_url"
    t.datetime "receipt_uploaded_at"
    t.index ["assigned_store_id", "status"], name: "index_orders_on_assigned_store_id_and_status", comment: "For store-specific order management"
    t.index ["assigned_store_id"], name: "index_orders_on_assigned_store_id"
    t.index ["created_at"], name: "index_orders_on_created_at", comment: "For order history and analytics queries"
    t.index ["driver_id", "status"], name: "index_orders_on_driver_id_and_status", where: "(driver_id IS NOT NULL)"
    t.index ["driver_id"], name: "index_orders_on_driver_id"
    t.index ["status", "created_at"], name: "index_orders_on_status_and_created_at", comment: "For filtering orders by status with time ordering"
    t.index ["tip_amount"], name: "index_orders_on_tip_amount"
    t.index ["user_id", "status", "created_at"], name: "index_orders_on_user_id_and_status_and_created_at"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id", "category_id"], name: "index_product_categories_on_product_id_and_category_id", unique: true
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.decimal "price", precision: 8, scale: 2
    t.text "description"
    t.boolean "in_stock", default: true
    t.integer "stock_quantity", default: 0
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "unit_id", null: false
    t.boolean "featured", default: false
    t.boolean "track_inventory", default: true, null: false
    t.index ["stock_quantity"], name: "index_products_on_stock_quantity", where: "(stock_quantity <= 10)"
    t.index ["track_inventory"], name: "index_products_on_track_inventory"
    t.index ["unit_id"], name: "index_products_on_unit_id"
  end

  create_table "sms_messages", force: :cascade do |t|
    t.string "phone"
    t.text "message"
    t.integer "status"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stores", force: :cascade do |t|
    t.string "name", null: false
    t.text "address", null: false
    t.string "phone"
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_stores_on_active"
    t.index ["latitude", "longitude"], name: "index_stores_on_latitude_and_longitude"
    t.index ["name"], name: "index_stores_on_name"
  end

  create_table "units", force: :cascade do |t|
    t.string "name", null: false
    t.string "symbol", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "name"], name: "index_units_on_active_and_name"
    t.index ["name"], name: "index_units_on_name", unique: true
    t.index ["symbol"], name: "index_units_on_symbol", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.integer "role"
    t.string "phone"
    t.string "password_digest"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_online", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role", "active"], name: "index_users_on_role_and_active"
    t.index ["role", "is_online"], name: "index_users_on_role_and_is_online"
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.integer "year", null: false
    t.string "color", null: false
    t.string "license_plate", null: false
    t.integer "vehicle_type", default: 0, null: false
    t.integer "verification_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_plate"], name: "index_vehicles_on_license_plate", unique: true
    t.index ["user_id"], name: "index_vehicles_on_user_id", unique: true
    t.index ["verification_status"], name: "index_vehicles_on_verification_status"
  end

  add_foreign_key "addresses", "users"
  add_foreign_key "driver_stats", "users"
  add_foreign_key "favorites", "products"
  add_foreign_key "favorites", "users"
  add_foreign_key "order_events", "orders"
  add_foreign_key "order_events", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "order_items", "products", column: "substitute_product_id"
  add_foreign_key "orders", "stores", column: "assigned_store_id"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "driver_id"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products"
  add_foreign_key "products", "units"
  add_foreign_key "vehicles", "users"
end
