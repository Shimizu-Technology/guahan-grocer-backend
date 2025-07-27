# app/services/s3_uploader.rb
require "aws-sdk-s3"

class S3Uploader
  class ConfigurationError < StandardError; end
  class UploadError < StandardError; end

  # Allowed image types for product uploads
  ALLOWED_CONTENT_TYPES = [
    'image/jpeg',
    'image/jpg', 
    'image/png',
    'image/webp'
  ].freeze

  # Maximum file size (10MB)
  MAX_FILE_SIZE = 10.megabytes

  # Uploads product image to S3, returning the S3 key and public URL
  def self.upload_product_image(file, product_id, original_filename = nil)
    validate_file!(file)
    
    # Generate a unique filename with product context
    timestamp = Time.current.to_i
    extension = File.extname(original_filename || file.original_filename)
    safe_filename = "products/#{product_id}/#{timestamp}#{extension}"
    
    upload_to_s3(file, safe_filename)
  end

  # Generic upload method (for future use with other image types)
  def self.upload(file, custom_path = nil)
    validate_file!(file)
    
    filename = custom_path || generate_filename(file)
    upload_to_s3(file, filename)
  end

  # Delete an image from S3 by its key
  def self.delete(s3_key)
    validate_configuration!
    
    s3_client = build_s3_client
    bucket_name = ENV["AWS_S3_BUCKET"] || ENV["AWS_BUCKET"]
    
    begin
      s3_client.delete_object(bucket: bucket_name, key: s3_key)
      Rails.logger.info "Deleted S3 object: #{s3_key}"
      true
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "Failed to delete S3 object #{s3_key}: #{e.message}"
      false
    end
  end

  # Check if an object exists in S3
  def self.exists?(s3_key)
    validate_configuration!
    
    s3_client = build_s3_client
    bucket_name = ENV["AWS_S3_BUCKET"] || ENV["AWS_BUCKET"]
    
    begin
      s3_client.head_object(bucket: bucket_name, key: s3_key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "Error checking S3 object existence #{s3_key}: #{e.message}"
      false
    end
  end

  # Get the public URL for an S3 key
  def self.public_url(s3_key)
    return nil if s3_key.blank?
    
    bucket_name = ENV["AWS_S3_BUCKET"] || ENV["AWS_BUCKET"]
    region = ENV["AWS_REGION"]
    
    "https://#{bucket_name}.s3.#{region}.amazonaws.com/#{s3_key}"
  end

  # Get Imgix URL (for future CDN integration)
  def self.imgix_url(s3_key, transformations = {})
    return nil if s3_key.blank?
    
    imgix_domain = ENV["IMGIX_DOMAIN"]
    return public_url(s3_key) if imgix_domain.blank?
    
    base_url = "https://#{imgix_domain}/#{s3_key}"
    
    if transformations.any?
      params = transformations.map { |k, v| "#{k}=#{v}" }.join('&')
      "#{base_url}?#{params}"
    else
      base_url
    end
  end

  private

  def self.validate_file!(file)
    raise UploadError, "No file provided" if file.nil?
    
    # Check file size
    if file.size > MAX_FILE_SIZE
      file_size_mb = (file.size / 1.megabyte.to_f).round(2)
      max_size_mb = MAX_FILE_SIZE / 1.megabyte
      raise UploadError, "File size too large (#{file_size_mb}MB). Maximum size is #{max_size_mb}MB"
    end
    
    # Check content type
    content_type = file.content_type || Marcel::MimeType.for(file)
    unless ALLOWED_CONTENT_TYPES.include?(content_type)
      raise UploadError, "Invalid file type. Allowed types: #{ALLOWED_CONTENT_TYPES.join(', ')}"
    end
  end

  def self.validate_configuration!
    required_vars = %w[AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY]
    missing_vars = required_vars.select { |var| ENV[var].blank? }
    
    # Check for bucket name (either AWS_S3_BUCKET or AWS_BUCKET)
    bucket_name = ENV["AWS_S3_BUCKET"] || ENV["AWS_BUCKET"]
    if bucket_name.blank?
      missing_vars << "AWS_S3_BUCKET or AWS_BUCKET"
    end
    
    if missing_vars.any?
      raise ConfigurationError, "Missing S3 configuration: #{missing_vars.join(', ')}"
    end
  end

  def self.build_s3_client
    Aws::S3::Client.new(
      region: ENV["AWS_REGION"],
      credentials: Aws::Credentials.new(
        ENV["AWS_ACCESS_KEY_ID"],
        ENV["AWS_SECRET_ACCESS_KEY"]
      )
    )
  end

  def self.upload_to_s3(file, s3_key)
    validate_configuration!
    
    s3_client = build_s3_client
    bucket_name = ENV["AWS_S3_BUCKET"] || ENV["AWS_BUCKET"]
    
    begin
      # Upload with proper content type (no ACL needed with bucket policy)
      s3_client.put_object(
        bucket: bucket_name,
        key: s3_key,
        body: file.read,
        content_type: file.content_type || Marcel::MimeType.for(file)
        # Note: Removed 'acl: public-read' since ACLs are disabled
        # Public access is handled by bucket policy instead
      )
      
      public_url = public_url(s3_key)
      
      Rails.logger.info "Successfully uploaded to S3: #{s3_key}"
      
      {
        s3_key: s3_key,
        public_url: public_url,
        imgix_url: imgix_url(s3_key)
      }
      
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3 upload failed for #{s3_key}: #{e.message}"
      raise UploadError, "Failed to upload image: #{e.message}"
    end
  end

  def self.generate_filename(file)
    timestamp = Time.current.to_i
    extension = File.extname(file.original_filename)
    safe_name = File.basename(file.original_filename, extension).gsub(/[^\w\-]/, '_')
    
    "uploads/#{timestamp}_#{safe_name}#{extension}"
  end
end 