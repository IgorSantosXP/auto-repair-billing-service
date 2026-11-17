module Billing
  module Entities
    class Budget < ApplicationRecord
      self.table_name = "budgets"

      STATUSES = %w[pending_approval approved rejected paid cancelled refunded].freeze

      has_many :items, class_name: "Billing::Entities::BudgetItem", dependent: :destroy, inverse_of: :budget
      has_many :payments, class_name: "Payments::Entities::Payment", dependent: :destroy, inverse_of: :budget

      before_validation :recalculate_total, if: -> { items.any? }

      validates :service_order_uuid, presence: true, uniqueness: true
      validates :customer_id, presence: true
      validates :status, inclusion: { in: STATUSES }
      validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      def recalculate_total
        self.total_cents = items.sum { |item| item.quantity.to_i * item.unit_price_cents.to_i }
      end

      def latest_payment
        payments.max_by(&:id)
      end

      def pending_approval?
        status == "pending_approval"
      end
    end
  end
end
