class AdminNotificationJob < ApplicationJob
  queue_as :default

  ADMIN_PHONE = "+16714830219"

  def perform(type:, message:)
    Rails.logger.warn("[AdminNotificationJob] #{type.upcase}: #{message}")
    
    case type
    when 'sms_limit_reached'
      Rails.logger.error("[ADMIN ALERT] SMS spending limit reached: #{message}")
      send_admin_sms("🚨 ALERT: #{message}")
    when 'critical_error'
      Rails.logger.error("[ADMIN ALERT] Critical error: #{message}")
      send_admin_sms("⚠️ ERROR: #{message}")
    when 'high_sms_usage'
      Rails.logger.warn("[ADMIN WARNING] High SMS usage: #{message}")
      send_admin_sms("📊 WARNING: #{message}")
    else
      Rails.logger.info("[ADMIN INFO] #{message}")
      # Don't send SMS for non-critical messages to avoid spam
    end
  end

  private

  def send_admin_sms(message)
    # Use ClickSend directly to bypass SMS cost limits for admin alerts
    success = ClicksendClient.send_text_message(
      to: ADMIN_PHONE,
      body: "[Guahan Grocer] #{message}",
      from: "GGrocer"
    )
    
    if success
      Rails.logger.info("[AdminNotificationJob] Admin SMS sent successfully")
    else
      Rails.logger.error("[AdminNotificationJob] Failed to send admin SMS - check ClickSend logs")
    end
  rescue StandardError => e
    Rails.logger.error("[AdminNotificationJob] Error sending admin SMS: #{e.message}")
  end
end