class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  belongs_to :substitute_product, class_name: 'Product', optional: true
  has_many :weight_variance_approvals, dependent: :destroy

  # Status enum as specified in the plan
  enum :status, { pending: 0, found: 1, unavailable: 2, substituted: 3 }
  
  # Variance approval method enum
  enum :variance_approval_method, {
    auto: 'auto',
    manual: 'manual',
    timeout_auto: 'timeout_auto'
  }, allow_nil: true

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  
  # Weight-based validations
  validates :estimated_weight, 
    numericality: { greater_than: 0 }, 
    allow_nil: true
  validates :actual_weight, 
    numericality: { greater_than: 0 }, 
    allow_nil: true
  validates :estimated_price, 
    numericality: { greater_than: 0 }, 
    allow_nil: true
  validates :actual_price, 
    numericality: { greater_than: 0 }, 
    allow_nil: true
  validates :variance_percentage,
    numericality: { greater_than_or_equal_to: -100, less_than_or_equal_to: 1000 },
    allow_nil: true
  
  # Custom validations
  validate :weight_within_product_range, if: :weight_based?
  
  # Scopes
  scope :weight_based, -> { joins(:product).where(products: { weight_based: true }) }
  scope :fixed_price, -> { joins(:product).where(products: { weight_based: false }) }
  scope :with_weight_variance, -> { where.not(variance_percentage: nil) }
  scope :pending_variance_approval, -> { where(variance_approved: nil) }
  scope :variance_approved, -> { where(variance_approved: true) }
  scope :variance_rejected, -> { where(variance_approved: false) }
  scope :weight_verified, -> { where.not(weight_verified_at: nil) }
  
  # Callbacks
  before_validation :set_pricing_for_weight_based_items
  before_save :calculate_variance_percentage, if: :weight_changed?
  after_update :create_variance_approval_if_needed, if: :should_create_variance_approval?
  
  # Weight-based item methods
  def weight_based?
    product&.weight_based?
  end
  
  def fixed_price?
    !weight_based?
  end
  
  # Set up estimated values for weight-based items
  def initialize_weight_based_item(requested_weight)
    return unless weight_based?
    
    self.estimated_weight = requested_weight
    self.estimated_price = product.calculate_price_for_weight(requested_weight)
    self.price = estimated_price # Set initial price to estimated
  end
  
  # Update actual weight and calculate new pricing
  def update_actual_weight!(new_weight, driver_note = nil)
    raise ArgumentError, "Item is not weight-based" unless weight_based?
    raise ArgumentError, "Weight must be positive" if new_weight <= 0
    raise ArgumentError, "Weight #{new_weight} is outside allowed range #{product.weight_range_text}" unless product.weight_in_range?(new_weight)
    
    old_weight = actual_weight
    old_price = actual_price
    
    self.actual_weight = new_weight
    self.actual_price = product.calculate_price_for_weight(new_weight)
    self.weight_verified_at = Time.current
    self.substitution_reason = driver_note if driver_note.present?
    
    # For weight-based items, mark as found when weight is verified
    # Use the actual weight as the found quantity for weight-based items
    self.found_quantity = new_weight
    self.status = 'found'
    
    # Calculate variance
    calculate_variance_percentage
    
    # Save changes
    if save
      Rails.logger.info "Updated weight for order item #{id}: #{old_weight} → #{new_weight} #{product.weight_unit} (marked as found)"
      
      # Create weight updated event
      order.add_event('weight_updated', nil, nil, {
        item_id: id,
        item_name: product.name,
        old_weight: old_weight,
        new_weight: new_weight,
        weight_unit: product.weight_unit,
        estimated_weight: estimated_weight,
        variance_percentage: variance_percentage,
        driver_note: driver_note,
        driver_name: order.driver&.name
      })
      
      # Auto-approve if eligible
      auto_approve_variance_if_eligible
      
      true
    else
      Rails.logger.error "Failed to update weight for order item #{id}: #{errors.full_messages.join(', ')}"
      raise ActiveRecord::RecordInvalid, self
    end
  end
  
  # Check if variance needs customer approval
  def needs_customer_approval?
    return false unless weight_based?
    return false unless variance_percentage.present?
    return false unless variance_approved.nil? # Already approved or rejected
    
    # No approval needed for 0% variance
    return false if variance_percentage == 0
    
    customer = order.user
    abs_variance = variance_percentage.abs
    
    # If auto-approval is disabled, always require approval
    return true unless customer.auto_approve_variances?
    
    # If variance is within tolerance, check overage-only setting
    if abs_variance <= customer.max_auto_variance_percentage
      if customer.auto_approve_overages_only?
        # Only auto-approve overages (positive variance), require approval for shortages
        return variance_percentage <= 0
      else
        # Auto-approve both overages and shortages within tolerance
        return false
      end
    end
    
    # Requires approval for variances exceeding tolerance
    true
  end
  
  # Auto-approve variance if within customer's tolerance
  def auto_approve_variance_if_eligible
    return unless weight_based?
    return if !variance_approved.nil? # Already decided (true or false)
    
    customer = order.user
    
    if !needs_customer_approval?
      approve_variance!('auto')
      Rails.logger.info "Auto-approved variance for order item #{id}: #{variance_percentage}%"
      
      # Create auto-approval event
      order.add_event('variance_auto_approved', nil, nil, {
        item_id: id,
        item_name: product.name,
        variance_percentage: "#{variance_percentage > 0 ? '+' : ''}#{variance_percentage.round(1)}",
        estimated_weight: estimated_weight,
        actual_weight: actual_weight,
        weight_unit: product.weight_unit,
        customer_settings: {
          auto_approve_enabled: customer.auto_approve_variances?,
          max_variance: customer.max_auto_variance_percentage,
          overages_only: customer.auto_approve_overages_only?
        }
      })
      
      true
    else
      # Create approval request event
      order.add_event('variance_approval_requested', nil, nil, {
        item_id: id,
        item_name: product.name,
        variance_percentage: "#{variance_percentage > 0 ? '+' : ''}#{variance_percentage.round(1)}",
        estimated_weight: estimated_weight,
        actual_weight: actual_weight,
        weight_unit: product.weight_unit,
        estimated_price: estimated_price,
        actual_price: actual_price,
        price_difference: actual_price - estimated_price
      })
      
      false
    end
  end
  
  # Approve weight variance
  def approve_variance!(method = 'manual')
    update!(
      variance_approved: true,
      variance_approval_method: method
    )
    
    # Create approval event (only for manual approvals, auto is handled elsewhere)
    if method == 'manual'
      order.add_event('variance_approved', order.user, nil, {
        item_id: id,
        item_name: product.name,
        variance_percentage: "#{variance_percentage > 0 ? '+' : ''}#{variance_percentage.round(1)}",
        estimated_weight: estimated_weight,
        actual_weight: actual_weight,
        weight_unit: product.weight_unit,
        estimated_price: estimated_price,
        actual_price: actual_price,
        price_difference: actual_price - estimated_price,
        approval_method: method,
        customer_name: order.user&.name
      })
    end
    
    # Send notification
    NotificationService.send_variance_approved_notification(self)
  end
  
  # Reject weight variance
  def reject_variance!(method = 'manual')
    update!(
      variance_approved: false,
      variance_approval_method: method
    )
    
    # Create rejection event
    order.add_event('variance_rejected', order.user, nil, {
      item_id: id,
      item_name: product.name,
      variance_percentage: "#{variance_percentage > 0 ? '+' : ''}#{variance_percentage.round(1)}",
      estimated_weight: estimated_weight,
      actual_weight: actual_weight,
      weight_unit: product.weight_unit,
      estimated_price: estimated_price,
      actual_price: actual_price,
      price_difference: actual_price - estimated_price,
      approval_method: method,
      customer_name: order.user&.name
    })
    
    # Send notification
    NotificationService.send_variance_rejected_notification(self)
  end
  
  # Get final price for billing
  def final_price
    if weight_based? && actual_price.present?
      actual_price
    else
      price
    end
  end
  
  # Get final quantity for billing
  def final_quantity
    found_quantity || quantity
  end
  
  # Get total line amount
  def line_total
    if weight_based?
      # For weight-based items, final_price already includes the weight calculation
      final_price
    else
      # For unit-based items, multiply price by quantity
      final_price * final_quantity
    end
  end
  
  # Get weight display information
  def weight_display_info
    return nil unless weight_based?
    
    {
      estimated_weight: estimated_weight,
      actual_weight: actual_weight,
      weight_unit: product.weight_unit,
      estimated_price: estimated_price,
      actual_price: actual_price,
      variance_percentage: variance_percentage,
      variance_approved: variance_approved,
      weight_verified: weight_verified_at.present?,
      needs_approval: needs_customer_approval?
    }
  end
  
  # Get price difference for variance
  def price_variance
    return 0 unless weight_based? && actual_price.present? && estimated_price.present?
    
    actual_price - estimated_price
  end
  
  # Get weight difference for variance  
  def weight_variance
    return 0 unless weight_based? && actual_weight.present? && estimated_weight.present?
    
    actual_weight - estimated_weight
  end
  
  # Check if weight has been updated
  def weight_updated?
    weight_based? && actual_weight.present? && estimated_weight.present? && actual_weight != estimated_weight
  end
  
  private
  
  # Calculate variance percentage between estimated and actual weight
  def calculate_variance_percentage
    return unless weight_based? && estimated_weight.present? && actual_weight.present?
    
    if estimated_weight == 0
      self.variance_percentage = 0
    else
      self.variance_percentage = ((actual_weight - estimated_weight) / estimated_weight * 100).round(2)
    end
  end
  
  # Set pricing for weight-based items during order creation
  def set_pricing_for_weight_based_items
    return unless weight_based?
    
    # For weight-based items, if estimated_weight is nil but we have quantity,
    # use quantity as the estimated weight (quantity represents requested weight)
    if estimated_weight.blank? && quantity.present?
      self.estimated_weight = quantity
    end
    
    # If we have estimated weight but no estimated price, calculate it
    if estimated_weight.present? && estimated_price.blank?
      self.estimated_price = product.calculate_price_for_weight(estimated_weight)
    end
    
    # Set the base price if it's 0 or blank for weight-based items
    if (price.blank? || price == 0) && estimated_price.present?
      self.price = estimated_price
    end
    
    # If we have actual weight but no actual price, calculate it
    if actual_weight.present? && actual_price.blank?
      self.actual_price = product.calculate_price_for_weight(actual_weight)
    end
  end
  
  # Check if weight fields changed
  def weight_changed?
    estimated_weight_changed? || actual_weight_changed?
  end
  
  # Check if we should create a variance approval
  def should_create_variance_approval?
    weight_based? && 
    variance_percentage.present? && 
    variance_percentage != 0 &&
    needs_customer_approval? &&
    variance_approved.nil? &&
    weight_variance_approvals.pending_approval.empty?
  end
  
  # Create variance approval request
  def create_variance_approval_if_needed
    return unless should_create_variance_approval?
    
    WeightVarianceApproval.create_approval!(
      self,
      estimated_weight,
      actual_weight,
      substitution_reason
    )
    
    Rails.logger.info "Created variance approval request for order item #{id}: #{variance_percentage}%"
    
    # Send notification to customer
    NotificationService.send_variance_approval_notification(self)
  end
  
  private
  
  # Custom validation: ensure weights are within product range
  def weight_within_product_range
    if estimated_weight.present? && !product.weight_in_range?(estimated_weight)
      errors.add(:estimated_weight, "must be within #{product.weight_range_text}")
    end
    
    if actual_weight.present? && !product.weight_in_range?(actual_weight)
      errors.add(:actual_weight, "must be within #{product.weight_range_text}")
    end
  end
end
