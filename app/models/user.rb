class User < ApplicationRecord
  has_secure_password

  # Associations as specified in the plan
  has_many :orders, dependent: :destroy
  has_many :driver_orders, class_name: 'Order', foreign_key: 'driver_id'
  has_many :favorites, dependent: :destroy
  has_many :favorite_products, through: :favorites, source: :product
  has_many :driver_stats, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_one :vehicle, dependent: :destroy

  # Role enum as specified in the plan
  enum :role, { customer: 0, driver: 1, admin: 2 }

  # Email normalization
  before_save :normalize_email

  # Basic validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :phone, presence: true, format: { with: /\A[\+]?[0-9\-\(\)\s]+\z/ }
  validates :role, presence: true

  # Address helper methods
  def default_address
    addresses.find_by(is_default: true)
  end

  def has_addresses?
    addresses.exists?
  end

  # Online status helper methods
  def online?
    is_online?
  end

  def offline?
    !is_online?
  end

  def go_online!
    return false unless driver?
    update!(is_online: true)
  end

  def go_offline!
    return false unless driver?
    update!(is_online: false)
  end

  # Scopes for finding online drivers
  scope :online_drivers, -> { where(role: :driver, is_online: true) }
  scope :offline_drivers, -> { where(role: :driver, is_online: false) }

  # Vehicle helper methods
  def has_verified_vehicle?
    vehicle&.verified?
  end

  def can_deliver?
    driver? && has_verified_vehicle?
  end

  def vehicle_verification_status
    return 'none' unless driver?
    return 'missing' unless vehicle.present?
    vehicle.verification_status
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
