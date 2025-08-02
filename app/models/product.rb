class Product < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: :track_inventory?
  validates :track_inventory, inclusion: { in: [true, false] }

  # Associations
  belongs_to :unit
  has_many :order_items, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories

  # Scopes for easier querying
  scope :in_stock, -> { where(in_stock: true) }
  scope :available, -> { 
    where('track_inventory = ? OR (track_inventory = ? AND in_stock = ? AND stock_quantity > ?)', 
          false, true, true, 0)
  }
  scope :by_category, ->(category_name) { joins(:categories).where(categories: { name: category_name }) if category_name.present? }
  scope :by_categories, ->(category_names) { joins(:categories).where(categories: { name: category_names }) if category_names.present? }
  scope :low_stock, -> { where(track_inventory: true).where('stock_quantity <= ?', 10) }
  scope :tracked_inventory, -> { where(track_inventory: true) }
  scope :unlimited_stock, -> { where(track_inventory: false) }
  scope :featured, -> { where(featured: true) }

  # Image handling methods
  def image_url
    return nil if self[:image_url].blank?
    
    # If the stored value is already a full URL, return it as-is
    # This handles seed data with external URLs (like Unsplash)
    if self[:image_url].starts_with?('http')
      return self[:image_url]
    end
    
    # Otherwise, treat it as an S3 key and generate the URL
    # Try Imgix first (for CDN), fallback to S3
    S3Uploader.imgix_url(self[:image_url]) || S3Uploader.public_url(self[:image_url])
  end

  def image_url_with_transformations(transformations = {})
    return nil if self[:image_url].blank?
    
    # If it's an external URL, return as-is (can't apply transformations)
    if self[:image_url].starts_with?('http')
      return self[:image_url]
    end
    
    # Use Imgix with transformations if available
    S3Uploader.imgix_url(self[:image_url], transformations)
  end

  # Get different image sizes for different use cases
  def thumbnail_url(size = 150)
    image_url_with_transformations(w: size, h: size, fit: 'crop', auto: 'compress,format')
  end

  def medium_image_url
    image_url_with_transformations(w: 400, h: 400, fit: 'crop', auto: 'compress,format')
  end

  def large_image_url
    image_url_with_transformations(w: 800, h: 600, fit: 'crop', auto: 'compress,format')
  end

  # Upload and set new image
  def upload_image(file)
    # Delete old image if exists (only if it's an S3 key, not external URL)
    delete_image if self[:image_url].present? && !self[:image_url].starts_with?('http')
    
    # Upload new image
    result = S3Uploader.upload_product_image(file, id)
    
    # Update the image_url
    update!(image_url: result[:s3_key])
    
    result
  rescue S3Uploader::UploadError => e
    Rails.logger.error "Failed to upload image for product #{id}: #{e.message}"
    raise e
  end

  # Delete current image
  def delete_image
    return false if self[:image_url].blank?
    
    # Can't delete external URLs, only S3 keys
    if self[:image_url].starts_with?('http')
      update!(image_url: nil)
      return true
    end
    
    success = S3Uploader.delete(self[:image_url])
    
    if success
      update!(image_url: nil)
    end
    
    success
  end

  # Check if product has an image
  def has_image?
    self[:image_url].present?
  end

  # Get image info for API responses
  def image_info
    return nil unless has_image?
    
    # For external URLs, all sizes return the same URL
    if self[:image_url].starts_with?('http')
      return {
        thumbnail: image_url,
        medium: image_url,
        large: image_url,
        original: image_url
      }
    end
    
    # For S3 keys, generate different sizes
    {
      thumbnail: thumbnail_url,
      medium: medium_image_url,
      large: large_image_url,
      original: image_url
    }
  end

  # Stock management helpers
  def in_stock?
    # Non-tracked inventory products are always in stock
    return true unless track_inventory?
    
    in_stock && stock_quantity > 0
  end

  def low_stock?
    # Non-tracked inventory products are never low stock
    return false unless track_inventory?
    
    stock_quantity <= 10
  end

  def out_of_stock?
    # Non-tracked inventory products are never out of stock
    return false unless track_inventory?
    
    !in_stock || stock_quantity <= 0
  end

  def available?
    # Non-tracked inventory products are always available
    return true unless track_inventory?
    
    in_stock?
  end

  def display_stock_status
    return 'Always Available' unless track_inventory?
    
    if out_of_stock?
      'Out of Stock'
    elsif low_stock?
      'Low Stock'
    else
      'In Stock'
    end
  end

  def display_stock_quantity
    return nil unless track_inventory?
    
    stock_quantity
  end

  # Update stock after order item is processed
  def reduce_stock!(quantity)
    # Skip stock reduction for non-tracked inventory products
    return true unless track_inventory?
    
    return false if quantity > stock_quantity
    
    new_quantity = stock_quantity - quantity
    update!(
      stock_quantity: new_quantity,
      in_stock: new_quantity > 0
    )
  end

  def increase_stock!(quantity)
    # Skip stock increase for non-tracked inventory products
    return true unless track_inventory?
    
    update!(
      stock_quantity: stock_quantity + quantity,
      in_stock: true
    )
  end

  # Ensure stock_quantity is 0 for non-tracked inventory products
  def normalize_stock_quantity
    unless track_inventory?
      self.stock_quantity = 0
      self.in_stock = true
    end
  end

  # Callbacks
  before_save :normalize_stock_quantity
end
