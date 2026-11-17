module Billing
  module UseCases
    class RejectBudget
      def self.call(...)
        new.call(...)
      end

      def call(service_order_uuid:, reason: "rejected_by_customer")
        ActiveRecord::Base.transaction do
          budget = Entities::Budget.lock.find_by(service_order_uuid: service_order_uuid)

          if budget.nil?
            Result.failure(errors: [ "Budget not found" ])
          elsif !budget.pending_approval?
            Result.failure(errors: [ "Budget is not pending approval (status: #{budget.status})" ])
          else
            budget.update!(status: "rejected", rejected_at: Time.current)
            Telemetry.budget_status("rejected")
            Services::EventPublisher.publish_for("billing.budget_rejected", budget, { reason: reason })
            Result.success(payload: budget)
          end
        end
      end
    end
  end
end
