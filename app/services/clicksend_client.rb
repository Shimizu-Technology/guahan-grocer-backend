require "net/http"
require "uri"
require "json"
require "base64"

class ClicksendClient
  BASE_URL = "https://rest.clicksend.com/v3"

  def self.send_text_message(to:, body:, from: nil)
    username = ENV["CLICKSEND_USERNAME"]
    api_key  = ENV["CLICKSEND_API_KEY"]
    approved_sender_id = ENV["CLICKSEND_APPROVED_SENDER_ID"]
    
    # Add debug logging for SMS attempt
    Rails.logger.debug("[ClicksendClient] Attempting to send SMS with params: to=#{to}, from=#{from}, body_length=#{body&.length}")

    if username.blank? || api_key.blank?
      Rails.logger.error("[ClicksendClient] Missing ClickSend credentials.")
      return false
    end

    # Use the approved sender ID if 'from' is not provided
    from ||= approved_sender_id

    # Ensure the 'from' field is not too long (ClickSend has an 11 character limit)
    if from.length > 11
      Rails.logger.warn("[ClicksendClient] 'from' field too long (#{from.length} chars), truncating to 11 chars")
      from = from[0...11]
    end

    # Basic Auth
    auth = Base64.strict_encode64("#{username}:#{api_key}")
    uri  = URI("#{BASE_URL}/sms/send")

    # Replace $ with USD symbol to avoid encoding issues
    encoded_body = body.gsub("$", "USD ")

    # Ensure phone number is in E.164 format (e.g., +16714830219)
    formatted_to = to.strip
    unless formatted_to.start_with?("+")
      formatted_to = "+#{formatted_to}"
    end

    # Build JSON payload for the API
    payload = {
      messages: [
        {
          source: "ruby_app",
          from:   from,
          body:   encoded_body,
          to:     formatted_to
        }
      ]
    }

    Rails.logger.info("[ClicksendClient] Sending SMS from '#{from}' to '#{formatted_to}'")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # Set aggressive timeouts for faster SMS delivery
    http.open_timeout = 5    # 5 seconds to establish connection
    http.read_timeout = 10   # 10 seconds to read response
    http.ssl_timeout = 5     # 5 seconds for SSL handshake
    
    # Keep connection alive for better performance
    http.keep_alive_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri, {
      "Authorization" => "Basic #{auth}",
      "Content-Type"  => "application/json",
      "Connection"    => "keep-alive"
    })
    request.body = payload.to_json

    begin
      start_time = Time.current
      response = http.request(request)
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.info("[ClicksendClient] API response received in #{duration}ms")
    rescue Net::TimeoutError => e
      Rails.logger.error("[ClicksendClient] Timeout error: #{e.message}")
      return false
    rescue StandardError => e
      Rails.logger.error("[ClicksendClient] HTTP request failed: #{e.message}")
      return false
    end

    Rails.logger.debug("[ClicksendClient] code=#{response.code}, body=#{response.body}")

    if response.code.to_i == 200
      json = JSON.parse(response.body) rescue {}
      if json["response_code"] == "SUCCESS"
        message_id = json.dig('data', 'messages', 0, 'message_id') rescue 'unknown'
        Rails.logger.info("[ClicksendClient] Sent SMS to #{to} - Message ID: #{message_id}")
        true
      else
        error_code = json["response_code"] rescue 'unknown'
        error_msg = json["response_msg"] rescue 'unknown'
        Rails.logger.error("[ClicksendClient] API Error: code=#{error_code}, message=#{error_msg}, full response=#{response.body}")
        false
      end
    else
      Rails.logger.error("[ClicksendClient] HTTP Error: code=#{response.code}, body=#{response.body}")
      false
    end
  end
end