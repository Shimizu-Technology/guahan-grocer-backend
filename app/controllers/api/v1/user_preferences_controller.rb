class Api::V1::UserPreferencesController < ApplicationController
  before_action :set_user

  # GET /api/v1/users/:user_id/preferences
  def show
    render json: {
      userId: @user.id.to_s,
      paymentPreferences: {
        autoApproveVariances: @user.auto_approve_variances,
        maxAutoVariancePercentage: @user.max_auto_variance_percentage,
        autoApproveOveragesOnly: @user.auto_approve_overages_only,
        varianceNotificationMethod: @user.variance_notification_method,
        approvalTimeoutMinutes: @user.approval_timeout_minutes
      },
      displaySettings: {
        autoApproveEnabled: @user.auto_approve_variances,
        toleranceLevel: tolerance_level_text(@user.max_auto_variance_percentage),
        notificationPreference: notification_preference_text(@user.variance_notification_method)
      }
    }
  end

  # PUT /api/v1/users/:user_id/preferences
  def update
    # Extract preferences from either nested or flat structure
    preferences_data = params.require(:preferences)
    payment_prefs = preferences_data[:paymentPreferences] || {}
    
    # Build update parameters with proper snake_case naming
    update_params = {}
    
    # Handle autoApproveVariances from multiple possible locations
    if payment_prefs[:autoApproveVariances].present?
      update_params[:auto_approve_variances] = payment_prefs[:autoApproveVariances]
    elsif preferences_data.key?(:autoApproveVariances)  # Use key? to handle false values
      update_params[:auto_approve_variances] = preferences_data[:autoApproveVariances]
    end
    
    # Handle maxAutoVariancePercentage from multiple possible locations
    if payment_prefs[:maxAutoVariancePercentage].present?
      update_params[:max_auto_variance_percentage] = payment_prefs[:maxAutoVariancePercentage]
    elsif preferences_data[:maxAutoVariancePercentage].present?
      update_params[:max_auto_variance_percentage] = preferences_data[:maxAutoVariancePercentage]
    end
    
    # Handle other payment preferences (use key? for boolean values that can be false)
    if payment_prefs.key?(:autoApproveOveragesOnly)
      update_params[:auto_approve_overages_only] = payment_prefs[:autoApproveOveragesOnly]
    elsif preferences_data.key?(:autoApproveOveragesOnly)
      update_params[:auto_approve_overages_only] = preferences_data[:autoApproveOveragesOnly]
    end
    
    if payment_prefs[:varianceNotificationMethod].present?
      update_params[:variance_notification_method] = payment_prefs[:varianceNotificationMethod]
    elsif preferences_data[:varianceNotificationMethod].present?
      update_params[:variance_notification_method] = preferences_data[:varianceNotificationMethod]
    end
    
    if payment_prefs[:approvalTimeoutMinutes].present?
      update_params[:approval_timeout_minutes] = payment_prefs[:approvalTimeoutMinutes]
    elsif preferences_data[:approvalTimeoutMinutes].present?
      update_params[:approval_timeout_minutes] = preferences_data[:approvalTimeoutMinutes]
    end

    Rails.logger.info "🔧 Received preferences data: #{preferences_data.inspect}"
    Rails.logger.info "🔧 Updating user preferences with: #{update_params.inspect}"

    if @user.update(update_params)
      render json: {
        success: true,
        message: 'Preferences updated successfully',
        preferences: {
          autoApproveVariances: @user.auto_approve_variances,
          maxAutoVariancePercentage: @user.max_auto_variance_percentage,
          autoApproveOveragesOnly: @user.auto_approve_overages_only,
          varianceNotificationMethod: @user.variance_notification_method,
          approvalTimeoutMinutes: @user.approval_timeout_minutes
        }
      }
    else
      Rails.logger.error "❌ Failed to update preferences: #{@user.errors.full_messages}"
      render json: {
        errors: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/users/:user_id/preferences/variance_settings
  def variance_settings
    render json: {
      toleranceOptions: [
        { value: 5, label: "Very Strict (5%)", description: "Only approve very small variances" },
        { value: 10, label: "Strict (10%)", description: "Approve small variances" },
        { value: 15, label: "Moderate (15%)", description: "Approve moderate variances" },
        { value: 20, label: "Flexible (20%)", description: "Approve larger variances" },
        { value: 25, label: "Very Flexible (25%)", description: "Approve most variances" }
      ],
      notificationOptions: [
        { value: "push", label: "Push Notifications", description: "Get notified via app notifications" },
        { value: "sms", label: "Text Messages", description: "Get notified via SMS" },
        { value: "email", label: "Email", description: "Get notified via email" }
      ],
      timeoutOptions: [
        { value: 5, label: "5 minutes", description: "Quick response required" },
        { value: 10, label: "10 minutes", description: "Standard response time" },
        { value: 15, label: "15 minutes", description: "More time to decide" },
        { value: 30, label: "30 minutes", description: "Extended response time" }
      ],
      currentSettings: {
        autoApproveVariances: @user.auto_approve_variances,
        maxAutoVariancePercentage: @user.max_auto_variance_percentage,
        autoApproveOveragesOnly: @user.auto_approve_overages_only,
        varianceNotificationMethod: @user.variance_notification_method,
        approvalTimeoutMinutes: @user.approval_timeout_minutes
      }
    }
  end

  private

  def set_user
    @user = User.find(params[:user_id])
    
    # Ensure user can only access their own preferences (unless admin)
    unless current_user.admin? || current_user.id == @user.id
      render json: { errors: ['Access denied'] }, status: :forbidden
      return
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['User not found'] }, status: :not_found
  end

  def tolerance_level_text(percentage)
    case percentage
    when 0..5
      "Very Strict"
    when 6..10
      "Strict"
    when 11..15
      "Moderate"
    when 16..20
      "Flexible"
    else
      "Very Flexible"
    end
  end

  def notification_preference_text(method)
    case method
    when 'push'
      'Push Notifications'
    when 'sms'
      'Text Messages'
    when 'email'
      'Email'
    else
      'Push Notifications'
    end
  end
end