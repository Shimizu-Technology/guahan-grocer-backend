class SmsMessage < ApplicationRecord
  # Status enum as specified in the plan
  enum :status, { pending: 0, sent: 1, delivered: 2, failed: 3 }

  # Validations
  validates :phone, presence: true, format: { with: /\A[\+]?[0-9\-\(\)\s]+\z/ }
  validates :message, presence: true
  validates :status, presence: true
end
