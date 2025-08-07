class SmsCostOptimizer
  # Cost optimization strategies for SMS notifications
  # Helps manage the 8-12 cents per SMS expense
  
  DAILY_SPENDING_LIMITS = {
    development: 10.0,   # $10/day in development
    production: 100.0    # $100/day in production
  }.freeze
  
  CACHE_KEY_PREFIX = "sms_spending"
  
  def self.can_send_sms?(cost_estimate = 0.10)
    return true if Rails.env.test? # Always allow in tests
    
    current_date = Date.current.strftime("%Y-%m-%d")
    cache_key = "#{CACHE_KEY_PREFIX}:#{current_date}"
    
    # Get current spending for today
    current_spending = Rails.cache.read(cache_key) || 0.0
    limit = DAILY_SPENDING_LIMITS[Rails.env.to_sym] || DAILY_SPENDING_LIMITS[:production]
    
    # Check if adding this SMS would exceed daily limit
    would_exceed = (current_spending + cost_estimate) > limit
    
    if would_exceed
      Rails.logger.warn("[SmsCostOptimizer] Daily SMS spending limit reached: $#{current_spending.round(2)}/$#{limit}")
      
      # Send alert to admin
      AdminNotificationJob.perform_later(
        type: 'sms_limit_reached',
        message: "SMS spending limit reached: $#{current_spending.round(2)}/$#{limit} on #{current_date}"
      )
    else
      # Check for high usage warning (80% of daily limit)
      usage_percentage = (current_spending / limit) * 100
      if usage_percentage >= 80 && !Rails.cache.exist?("#{CACHE_KEY_PREFIX}:warning_sent:#{current_date}")
        Rails.logger.warn("[SmsCostOptimizer] High SMS usage detected: #{usage_percentage.round(1)}%")
        
        # Send warning to admin (only once per day)
        AdminNotificationJob.perform_later(
          type: 'high_sms_usage',
          message: "SMS spending at #{usage_percentage.round(1)}% of daily limit ($#{current_spending.round(2)}/$#{limit})"
        )
        
        # Mark warning as sent for today
        Rails.cache.write("#{CACHE_KEY_PREFIX}:warning_sent:#{current_date}", true, expires_at: Date.current.end_of_day)
      end
    end
    
    !would_exceed
  end
  
  def self.record_sms_cost(cost = 0.10)
    return if Rails.env.test?
    
    current_date = Date.current.strftime("%Y-%m-%d")
    cache_key = "#{CACHE_KEY_PREFIX}:#{current_date}"
    
    # Update spending for today (expires at end of day)
    current_spending = Rails.cache.read(cache_key) || 0.0
    new_spending = current_spending + cost
    
    # Cache expires at end of day
    Rails.cache.write(cache_key, new_spending, expires_at: Date.current.end_of_day)
    
    Rails.logger.info("[SmsCostOptimizer] SMS cost recorded: +$#{cost.round(3)}, daily total: $#{new_spending.round(2)}")
  end
  
  def self.daily_spending_report
    current_date = Date.current.strftime("%Y-%m-%d")
    cache_key = "#{CACHE_KEY_PREFIX}:#{current_date}"
    
    current_spending = Rails.cache.read(cache_key) || 0.0
    limit = DAILY_SPENDING_LIMITS[Rails.env.to_sym] || DAILY_SPENDING_LIMITS[:production]
    
    {
      date: current_date,
      current_spending: current_spending.round(2),
      daily_limit: limit,
      remaining_budget: (limit - current_spending).round(2),
      utilization_percentage: ((current_spending / limit) * 100).round(1)
    }
  end
  
  # Duplicate message prevention
  def self.recently_sent_similar?(phone, message_template, order_id = nil)
    # In development, allow bypassing duplicate prevention for easier testing
    if Rails.env.development? && ENV['BYPASS_SMS_DUPLICATES'] == 'true'
      Rails.logger.info("[SmsCostOptimizer] Duplicate prevention bypassed in development")
      return false
    end
    
    # Create unique cache key that includes order ID to allow different orders
    # but prevents rapid duplicate sends for the same order
    cache_key = if order_id
                  "#{CACHE_KEY_PREFIX}:recent:#{phone}:#{message_template}:#{order_id}"
                else
                  "#{CACHE_KEY_PREFIX}:recent:#{phone}:#{message_template}"
                end
    
    if Rails.cache.exist?(cache_key)
      Rails.logger.warn("[SmsCostOptimizer] Duplicate SMS prevented: #{message_template} to #{phone} (order: #{order_id})")
      return true
    end
    
    # Mark as sent for 2 minutes (reduced from 5 for better testing experience)
    Rails.cache.write(cache_key, true, expires_in: 2.minutes)
    false
  end
end