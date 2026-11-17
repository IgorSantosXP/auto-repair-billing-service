module Billing
  module UseCases
    class CancelBudget
      NON_CANCELLABLE = %w[paid refunded].freeze

      def self.call(...)
        new.call(...)
      end

      def call(service_order_uuid:, saga_id:, reason: nil)
        ActiveRecord::Base.transaction do
          budget = Entities::Budget.lock.find_by(service_order_uuid: service_order_uuid)

          if budget.nil?
            Rails.logger.warn("[Billing] cancel_budget for unknown budget #{service_order_uuid}")
          elsif NON_CANCELLABLE.include?(budget.status)
            Rails.logger.warn("[Billing] Budget #{service_order_uuid} is #{budget.status}, not cancelling")
          elsif budget.status != "cancelled"
            budget.update!(status: "cancelled", cancelled_at: Time.current)
            Telemetry.budget_status("cancelled")
          end

          Services::EventPublisher.publish("billing.budget_cancelled",
                                           payload: { reason: reason }.compact,
                                           saga_id: budget&.saga_id || saga_id,
                                           service_order_uuid: service_order_uuid)
          Result.success(payload: budget)
        end
      end
    end
  end
end
