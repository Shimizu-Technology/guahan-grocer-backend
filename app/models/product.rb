class Product < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: :track_inventory?
  validates :track_inventory, inclusion: { in: [true, false] }
  validates :weight_based, inclusion: { in: [true, false] }
  validates :price_per_unit, presence: true, numericality: { greater_than: 0 }, if: :weight_based?
  validates :weight_unit, presence: true, length: { maximum: 20 }, if: :weight_based?
  validates :min_weight, numericality: { greater_than: 0 }, allow_nil: true, if: :weight_based?
  validates :max_weight, numericality: { greater_than: 0 }, allow_nil: true, if: :weight_based?
  validate :max_weight_greater_than_min_weight, if: :weight_based?
  
  # Open Food Facts validations
  validates :gtin, uniqueness: true, allow_nil: true
  validates :nutriscore_grade, inclusion: { in: %w[A B C D E], allow_nil: true }, 
            length: { maximum: 1 }

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
  scope :weight_based, -> { where(weight_based: true) }
  scope :fixed_price, -> { where(weight_based: false) }

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

  # Weight-based product methods
  def weight_based?
    weight_based == true
  end
  
  def fixed_price?
    !weight_based?
  end
  
  # Calculate price for a given weight
  def calculate_price_for_weight(weight)
    return price unless weight_based?
    
    (price_per_unit * weight).round(2)
  end
  
  # Get estimated price for display (uses price field as base weight for weight-based items)
  def display_price_info
    if weight_based?
      base_weight = 1.0 # Default to 1 unit for display
      estimated_price = calculate_price_for_weight(base_weight)
      
      {
        is_weight_based: true,
        price_per_unit: price_per_unit,
        weight_unit: weight_unit,
        estimated_price: estimated_price,
        display_text: "$#{price_per_unit}/#{weight_unit}"
      }
    else
      {
        is_weight_based: false,
        fixed_price: price,
        display_text: "$#{price}"
      }
    end
  end
  
  # Check if a weight is within acceptable range
  def weight_in_range?(weight)
    return true unless weight_based?
    
    within_min = min_weight.nil? || weight >= min_weight
    within_max = max_weight.nil? || weight <= max_weight
    
    within_min && within_max
  end
  
  # Get weight range text for display
  def weight_range_text
    return nil unless weight_based?
    
    if min_weight && max_weight
      "#{min_weight} - #{max_weight} #{weight_unit}"
    elsif min_weight
      "Min #{min_weight} #{weight_unit}"
    elsif max_weight
      "Max #{max_weight} #{weight_unit}"
    else
      "Any weight"
    end
  end
  
  # Calculate variance percentage between two weights
  def calculate_weight_variance(original_weight, new_weight)
    return 0 if original_weight == 0 || !weight_based?
    
    ((new_weight - original_weight) / original_weight * 100).round(2)
  end
  
  # Get weight unit display
  def weight_unit_display
    weight_based? ? weight_unit : unit&.abbreviation
  end

  # Open Food Facts helper methods
  def has_gtin?
    gtin.present?
  end

  def has_enhanced_data?
    has_gtin? || brand.present? || nutrition_data.present? || image_urls.any? || 
    serving_size.present? || ingredients_text.present? || off_categories.present?
  end

  def primary_image_url
    # Prefer Open Food Facts images, fallback to existing image_url
    if image_urls.any?
      image_urls.first
    else
      image_url
    end
  end

  def all_image_urls
    # Combine Open Food Facts images with existing image
    urls = image_urls.dup || []
    urls << image_url if image_url.present? && !urls.include?(image_url)
    urls << image_ingredients_url if image_ingredients_url.present?
    urls << image_nutrition_url if image_nutrition_url.present?
    urls.compact.uniq
  end

  def has_nutrition_data?
    nutrition_data.present? && nutrition_data.any?
  end

  def calories_per_100g
    return nil unless has_nutrition_data?
    nutrition_data['energy_kcal_100g']
  end

  def ingredients_list
    ingredients_text.presence || (nutrition_data&.dig('ingredients_text'))
  end

  def allergens_list
    allergens.presence
  end

  # Enhanced helper methods for new fields
  def has_allergen_info?
    allergens.present? || traces.present?
  end

  def has_health_scores?
    nutriscore_grade.present? || nova_group.present?
  end

  def nutriscore_display
    return nil unless nutriscore_grade.present?
    nutriscore_grade.upcase
  end

  def nova_display
    return nil unless nova_group.present?
    case nova_group
    when 1 then "Unprocessed"
    when 2 then "Processed culinary ingredients"
    when 3 then "Processed foods"
    when 4 then "Ultra-processed foods"
    else "Unknown"
    end
  end

  def categories_list
    return [] unless off_categories.present?
    off_categories.split(',').map(&:strip)
  end

  def labels_list
    return [] unless off_labels.present?
    off_labels.split(',').map(&:strip)
  end

  def has_multiple_images?
    all_image_urls.length > 1
  end

  def is_food_product?
    # Heuristic: if it has nutrition data, allergens, or food-related categories, it's likely food
    has_nutrition_data? || allergens.present? || 
    (off_categories.present? && off_categories.match?(/food|drink|beverage|snack|meal/i))
  end

  # Class methods for Open Food Facts integration
  def self.find_by_gtin(gtin)
    find_by(gtin: gtin) if gtin.present?
  end

  def self.create_from_open_food_facts(gtin, admin_price = nil)
    return nil if gtin.blank?

    # Check if product already exists
    existing_product = find_by_gtin(gtin)
    return existing_product if existing_product

    # Fetch from Open Food Facts
    product_data = OpenFoodFactsService.fetch_by_gtin(gtin)
    return nil unless product_data

    # Create new product with all Open Food Facts data
    create!(
      # Basic info
      gtin: product_data[:gtin],
      name: product_data[:name] || "Product #{gtin}",
      brand: product_data[:brand],
      size: product_data[:size],
      description: product_data[:description],
      
      # Enhanced fields (all optional)
      serving_size: product_data[:serving_size],
      ingredients_text: product_data[:ingredients_text],
      allergens: product_data[:allergens],
      traces: product_data[:traces],
      off_categories: product_data[:off_categories],
      off_labels: product_data[:off_labels],
      nutriscore_grade: product_data[:nutriscore_grade],
      nova_group: product_data[:nova_group],
      packaging: product_data[:packaging],
      
      # Images
      image_urls: product_data[:image_urls] || [],
      image_ingredients_url: product_data[:image_ingredients_url],
      image_nutrition_url: product_data[:image_nutrition_url],
      
      # Existing fields
      nutrition_data: product_data[:nutrition_data] || {},
      price: admin_price || 0.0, # Admin must set price
      track_inventory: false, # Default to unlimited stock
      weight_based: false, # Default to fixed price
      unit: Unit.find_by(name: 'Each') || Unit.first # Default unit
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create product from Open Food Facts: #{e.message}"
    nil
  end

  private

  # Custom validation for weight range
  def max_weight_greater_than_min_weight
    return unless min_weight && max_weight
    
    if max_weight <= min_weight
      errors.add(:max_weight, "must be greater than minimum weight")
    end
  end

  # Callbacks
  before_save :normalize_stock_quantity
end
