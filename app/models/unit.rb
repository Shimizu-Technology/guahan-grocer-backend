class Unit < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :symbol, presence: true, uniqueness: { case_sensitive: false }
  validates :name, length: { minimum: 1, maximum: 30 }
  validates :symbol, length: { minimum: 1, maximum: 10 }
  
  # Associations
  has_many :products, dependent: :restrict_with_error
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }
  scope :by_symbol, -> { order(:symbol) }
  
  # Callbacks
  before_save :normalize_fields
  
  # Class methods
  def self.find_or_create_by_name(name, symbol = nil)
    symbol ||= name.downcase
    find_or_create_by(name: name.downcase, symbol: symbol.downcase)
  end
  
  # Instance methods
  def display_name
    "#{name} (#{symbol})"
  end
  
  def can_be_deleted?
    products.count == 0
  end
  
  private
  
  def normalize_fields
    self.name = name.strip.downcase if name.present?
    self.symbol = symbol.strip.downcase if symbol.present?
  end
end 