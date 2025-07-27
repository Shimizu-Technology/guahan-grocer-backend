class ProductCategory < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :category
  
  # Validations
  validates :product_id, presence: true
  validates :category_id, presence: true
  validates :product_id, uniqueness: { scope: :category_id }
  
  # Scopes
  scope :by_category, ->(category) { joins(:category).where(categories: { name: category }) }
  scope :by_product, ->(product) { where(product: product) }
  
  # Class methods
  def self.create_association(product, category)
    find_or_create_by(product: product, category: category)
  end
  
  def self.remove_association(product, category)
    find_by(product: product, category: category)&.destroy
  end
end 