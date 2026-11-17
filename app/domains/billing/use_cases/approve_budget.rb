module Billing
  module UseCases
    class ApproveBudget
      def self.call(...)
        new.call(...)
      end

      def initialize(gateway: nil)
        @gateway = gateway
      end

      def call(service_order_uuid:)
        outcome = ActiveRecord::Base.transaction do
          budget = Entities::Budget.lock.find_by(service_order_uuid: service_order_uuid)

          if budget.nil?
            { error: :not_found }
          elsif !budget.pending_approval?
            { error: :invalid_status, status: budget.status }
          else
            approve(budget)
          end
        end

        return failure(outcome) if outcome[:error]

        Services::Notifier.payment_link(outcome[:budget], payment_url: outcome[:payment].payment_url) if outcome[:payment].status == "pending"
        Result.success(payload: outcome)
      end

      private

      def approve(budget)
        budget.update!(status: "approved", approved_at: Time.current)
        Telemetry.budget_status("approved")

        payment = create_payment(budget)
        { budget: budget, payment: payment }
      end

      def create_payment(budget)
        gateway     = @gateway || Payments::Gateways::Factory.build
        preference  = gateway.create_preference(budget)

        payment = budget.payments.create!(
          provider:      "mercadopago",
          mode:          gateway.mode,
          preference_id: preference[:preference_id],
          status:        "pending",
          amount_cents:  budget.total_cents,
          payment_url:   preference[:payment_url]
        )
        Telemetry.payment_status("pending")
        Services::EventPublisher.publish_for("billing.budget_approved", budget,
                                             { budget_id: budget.uuid, payment_url: payment.payment_url })
        payment
      rescue Payments::Errors::GatewayError => e
        payment = budget.payments.create!(
          provider:       "mercadopago",
          mode:           gateway&.mode || Payments::Settings.mode,
          status:         "rejected",
          amount_cents:   budget.total_cents,
          failure_reason: e.message
        )
        Telemetry.payment_status("rejected")
        Services::EventPublisher.publish_for("billing.payment_failed", budget,
                                             { payment_id: payment.id.to_s, reason: e.message })
        payment
      end

      def failure(outcome)
        message = outcome[:error] == :not_found ? "Budget not found" : "Budget is not pending approval (status: #{outcome[:status]})"
        Result.failure(errors: [ message ])
      end
    end
  end
end
