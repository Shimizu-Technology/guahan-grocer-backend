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

ActiveRecord::Schema[8.0].define(version: 2025_07_25_105852) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "driver_stats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "total_deliveries", default: 0
    t.decimal "total_earnings", precision: 8, scale: 2, default: "0.0"
    t.decimal "average_rating", precision: 3, scale: 2
    t.integer "total_ratings", default: 0
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["driver_id", "status"], name: "index_orders_on_driver_id_and_status", where: "(driver_id IS NOT NULL)"
    t.index ["driver_id"], name: "index_orders_on_driver_id"
    t.index ["user_id", "status", "created_at"], name: "index_orders_on_user_id_and_status_and_created_at"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "category"
    t.decimal "price", precision: 8, scale: 2
    t.string "unit"
    t.text "description"
    t.boolean "in_stock", default: true
    t.integer "stock_quantity", default: 0
    t.string "image_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "in_stock"], name: "index_products_on_category_and_in_stock"
    t.index ["stock_quantity"], name: "index_products_on_stock_quantity", where: "(stock_quantity <= 10)"
  end

  create_table "sms_messages", force: :cascade do |t|
    t.string "phone"
    t.text "message"
    t.integer "status"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role", "active"], name: "index_users_on_role_and_active"
  end

  add_foreign_key "driver_stats", "users"
  add_foreign_key "favorites", "products"
  add_foreign_key "favorites", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "order_items", "products", column: "substitute_product_id"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "driver_id"
end
