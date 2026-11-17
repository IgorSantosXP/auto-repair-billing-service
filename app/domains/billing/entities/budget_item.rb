module Billing
  module Entities
    class BudgetItem < ApplicationRecord
      self.table_name = "budget_items"

      KINDS = %w[service part].freeze

      belongs_to :budget, class_name: "Billing::Entities::Budget", inverse_of: :items

      before_validation :compute_total

      validates :kind, inclusion: { in: KINDS }
      validates :name, presence: true
      validates :quantity, numericality: { only_integer: true, greater_than: 0 }
      validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      private

      def compute_total
        self.total_cents = quantity.to_i * unit_price_cents.to_i
      end
    end
  end
end
