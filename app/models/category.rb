class Category < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :name, length: { minimum: 2, maximum: 50 }
  
  # Associations
  has_many :product_categories, dependent: :destroy
  has_many :products, through: :product_categories
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }
  
  # Callbacks
  before_save :normalize_name
  
  # Class methods
  def self.find_or_create_by_name(name)
    find_or_create_by(name: name.strip.titleize)
  end
  
  private
  
  def normalize_name
    self.name = name.strip.titleize if name.present?
  end
end 