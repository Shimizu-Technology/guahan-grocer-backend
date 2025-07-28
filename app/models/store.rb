class Store < ApplicationRecord
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :address, presence: true, length: { minimum: 10, maximum: 500 }
  validates :phone, format: { with: /\A[\d\-\(\)\+\s\.]+\z/, message: "must be a valid phone number" }, allow_blank: true
  validates :latitude, presence: true, numericality: { greater_than: -90, less_than: 90 }
  validates :longitude, presence: true, numericality: { greater_than: -180, less_than: 180 }
  validates :active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Class methods
  def self.closest_to(address_or_coords)
    DistanceCalculator.find_closest_store_to(address_or_coords)
  end

  # Instance methods
  def coordinates
    [latitude, longitude]
  end

  def full_address
    address
  end

  def display_name
    name
  end

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end
end
