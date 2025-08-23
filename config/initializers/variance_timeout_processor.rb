# Start the variance timeout processor
if Rails.env.production? || Rails.env.development?
  Rails.application.config.after_initialize do
    # Start the variance timeout processor job
    ProcessVarianceTimeoutsJob.set(wait: 1.minute).perform_later
    Rails.logger.info "Variance timeout processor started"
  end
end