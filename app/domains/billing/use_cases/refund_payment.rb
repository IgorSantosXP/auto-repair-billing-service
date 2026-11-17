module Billing
  module UseCases
    class RefundPayment
      REFUNDABLE = %w[approved refund_failed].freeze

      def self.call(...)
        new.call(...)
      end

      def initialize(gateway: nil)
        @gateway = gateway
      end

      def call(service_order_uuid:, saga_id:)
        ActiveRecord::Base.transaction do
          budget  = Entities::Budget.lock.find_by(service_order_uuid: service_order_uuid)
          payment = budget&.payments&.where(status: REFUNDABLE)&.order(:id)&.last
          saga_id = budget&.saga_id || saga_id

          if payment
            refund(budget, payment)
          elsif (done = budget&.payments&.find_by(status: "refunded"))
            # Redelivered command: the refund already happened, just tell the saga again.
            publish_refunded(budget, done)
            Result.success(payload: done)
          else
            fail_without_payment(service_order_uuid, saga_id)
          end
        end
      end

      private

      def refund(budget, payment)
        gateway = @gateway || Payments::Gateways::Factory.build

        begin
          refund = gateway.refund(payment)
        rescue StandardError => e
          return refund_failed(budget, payment, e.message)
        end

        payment.update!(status: "refunded", refund_id: refund[:id], failure_reason: nil)
        budget.update!(status: "refunded")
        Telemetry.payment_status("refunded")
        Telemetry.budget_status("refunded")
        publish_refunded(budget, payment)
        Result.success(payload: payment)
      end

      def refund_failed(budget, payment, reason)
        payment.update!(status: "refund_failed", failure_reason: reason)
        Telemetry.payment_status("refund_failed")
        Services::EventPublisher.publish_for("billing.refund_failed", budget, { reason: reason })
        Result.failure(errors: [ reason ])
      end

      def publish_refunded(budget, payment)
        Services::EventPublisher.publish_for(
          "billing.payment_refunded", budget,
          { payment_id: payment.id.to_s, refund_id: payment.refund_id, amount_cents: payment.amount_cents }
        )
      end

      def fail_without_payment(service_order_uuid, saga_id)
        Services::EventPublisher.publish("billing.refund_failed",
                                         payload: { reason: "no_approved_payment" },
                                         saga_id: saga_id, service_order_uuid: service_order_uuid)
        Result.failure(errors: [ "No approved payment to refund" ])
      end
    end
  end
end
