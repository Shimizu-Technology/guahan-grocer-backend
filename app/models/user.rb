class User < ApplicationRecord
  has_secure_password

  # Associations as specified in the plan
  has_many :orders, dependent: :destroy
  has_many :driver_orders, class_name: 'Order', foreign_key: 'driver_id'
  has_many :favorites, dependent: :destroy
  has_many :favorite_products, through: :favorites, source: :product
  has_many :driver_stats, dependent: :destroy

  # Role enum as specified in the plan
  enum :role, { customer: 0, driver: 1, admin: 2 }

  # Basic validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :phone, presence: true, format: { with: /\A[\+]?[0-9\-\(\)\s]+\z/ }
  validates :role, presence: true
end
