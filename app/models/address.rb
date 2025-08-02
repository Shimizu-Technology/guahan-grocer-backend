class Address < ApplicationRecord
  belongs_to :user

  # Validations
  validates :street_address, presence: true, length: { maximum: 255 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :state, presence: true, length: { maximum: 50 }
  validates :zip_code, presence: true, length: { maximum: 20 }
  validates :label, length: { maximum: 100 }, allow_blank: true
  validates :apartment_unit, length: { maximum: 50 }, allow_nil: true
  validates :latitude, numericality: { in: -90.0..90.0 }, allow_nil: true
  validates :longitude, numericality: { in: -180.0..180.0 }, allow_nil: true
  
  # Ensure only one default address per user
  validates :is_default, uniqueness: { scope: :user_id }, if: :is_default?

  # Callbacks
  before_save :ensure_single_default
  before_save :normalize_fields

  # Scopes
  scope :default_first, -> { order(is_default: :desc, created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # Instance methods
  def full_address
    parts = [street_address]
    parts << apartment_unit if apartment_unit.present?
    parts << "#{city}, #{state} #{zip_code}"
    parts.join(', ')
  end

  def display_label
    label.present? ? label : 'Address'
  end

  def coordinates
    return nil unless latitude.present? && longitude.present?
    [latitude, longitude]
  end

  def make_default!
    transaction do
      # Remove default from other addresses
      user.addresses.where(is_default: true).update_all(is_default: false)
      # Set this one as default
      update!(is_default: true)
    end
  end

  def to_order_format
    {
      street: street_address,
      apartment: apartment_unit,
      city: city,
      state: state,
      zip: zip_code,
      latitude: latitude,
      longitude: longitude
    }
  end

  private

  def ensure_single_default
    if is_default? && user.present?
      # If this is being set as default, unset others
      user.addresses.where.not(id: id).update_all(is_default: false)
    elsif is_default == false && user.present? && user.addresses.where(is_default: true).count == 1 && user.addresses.where(is_default: true).first == self
      # If this is the only default and we're trying to unset it, keep it as default
      self.is_default = true
    end
  end

  def normalize_fields
    self.label = label.present? ? label.strip : nil
    self.street_address = street_address.strip if street_address.present?
    self.apartment_unit = apartment_unit.present? ? apartment_unit.strip : nil
    self.city = city.strip if city.present?
    self.state = state.strip.upcase if state.present?
    self.zip_code = zip_code.strip if zip_code.present?
  end
end
