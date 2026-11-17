module Payments
  module Entities
    class Payment < ApplicationRecord
      self.table_name = "payments"

      STATUSES = %w[pending approved rejected refunded refund_failed].freeze

      belongs_to :budget, class_name: "Billing::Entities::Budget", inverse_of: :payments

      validates :provider, inclusion: { in: %w[mercadopago] }
      validates :mode, inclusion: { in: %w[fake live] }
      validates :status, inclusion: { in: STATUSES }
      validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    end
  end
end
