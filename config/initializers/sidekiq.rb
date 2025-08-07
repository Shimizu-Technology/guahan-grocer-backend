Sidekiq.configure_server do |config|
  config.redis = { 
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5
  }
  
  # Set queue priorities - critical SMS jobs processed first
  config.queues = ['critical', 'default', 'low']
end

Sidekiq.configure_client do |config|
  config.redis = { 
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    network_timeout: 5
  }
end

# Configure retry behavior
Sidekiq.default_job_options = {
  'backtrace' => true,
  'retry' => 3
}

# SMS jobs should retry faster and fail fast if ClickSend is down
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    Rails.logger.error("[Sidekiq] Job #{job['class']} died: #{ex.message}")
    
    # Alert admin if SMS jobs are failing
    if job['class'].include?('Sms') || job['class'].include?('SMS')
      AdminNotificationJob.perform_later(
        type: 'critical_error',
        message: "SMS job failed permanently: #{job['class']} - #{ex.message}"
      )
    end
  end
end