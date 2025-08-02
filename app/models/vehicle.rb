class Vehicle < ApplicationRecord
  belongs_to :user

  # Enums
  enum :verification_status, { 
    pending: 0, 
    verified: 1, 
    rejected: 2, 
    under_review: 3 
  }

  enum :vehicle_type, {
    sedan: 0,
    suv: 1,
    truck: 2,
    hatchback: 3,
    coupe: 4,
    convertible: 5,
    van: 6,
    minivan: 7,
    pickup: 8,
    other: 9
  }

  # Validations
  validates :make, presence: true, length: { maximum: 50 }
  validates :model, presence: true, length: { maximum: 50 }
  validates :year, presence: true, 
    numericality: { 
      greater_than: 1990, 
      less_than_or_equal_to: Date.current.year + 1 
    }
  validates :color, presence: true, length: { maximum: 30 }
  validates :license_plate, presence: true, length: { maximum: 15 }, 
    uniqueness: { case_sensitive: false, message: "is already registered" }
  validates :vehicle_type, inclusion: { in: vehicle_types.keys }
  validates :verification_status, inclusion: { in: verification_statuses.keys }
  validates :user_id, uniqueness: { message: "can only have one vehicle" }

  # Callbacks
  before_save :normalize_license_plate
  before_save :ensure_driver_role

  # Scopes
  scope :verified, -> { where(verification_status: :verified) }
  scope :pending_verification, -> { where(verification_status: :pending) }
  scope :for_driver, ->(user) { where(user: user) }

  # Helper methods
  def display_name
    "#{year} #{make} #{model}"
  end

  def full_description
    "#{display_name} (#{color}, #{license_plate})"
  end

  def needs_verification?
    pending? || rejected?
  end

  def can_be_used_for_delivery?
    verified? && user&.driver?
  end

  private

  def normalize_license_plate
    self.license_plate = license_plate.upcase.strip if license_plate.present?
  end

  def ensure_driver_role
    unless user&.driver?
      errors.add(:user, "must be a driver to register a vehicle")
      throw :abort
    end
  end
end
