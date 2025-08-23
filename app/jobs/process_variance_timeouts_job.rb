class ProcessVarianceTimeoutsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Processing variance timeouts..."
    
    # Find all variance approvals that have timed out
    timed_out_approvals = WeightVarianceApproval.joins(:order_item)
                                                .where(approval_status: 'pending')
                                                .where('timeout_at < ?', Time.current)
    
    processed_count = 0
    
    timed_out_approvals.find_each do |approval|
      begin
        Rails.logger.info "Processing timeout for variance approval #{approval.id}"
        
        # Mark as timed out
        approval.timeout!
        
        # Reject the variance on the order item
        approval.order_item.reject_variance!('timeout_auto')
        
        processed_count += 1
        
      rescue => e
        Rails.logger.error "Failed to process timeout for variance approval #{approval.id}: #{e.message}"
      end
    end
    
    Rails.logger.info "Processed #{processed_count} variance timeouts"
    
    # Schedule the next run in 1 minute
    ProcessVarianceTimeoutsJob.set(wait: 1.minute).perform_later
  end
end