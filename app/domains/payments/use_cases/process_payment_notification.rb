module Payments
  module UseCases
    # Shared by the Mercado Pago webhook and the fake-mode simulate endpoint.
    # Idempotent: a payment already in the reported status is left untouched.
    class ProcessPaymentNotification
      def self.call(...)
        new.call(...)
      end

      def initialize(gateway: nil)
        @gateway = gateway
      end

      def call(provider_payment_id:)
        gateway = @gateway || Gateways::Factory.build
        details = gateway.fetch_payment(provider_payment_id)

        ActiveRecord::Base.transaction do
          budget = Billing::Entities::Budget.lock.find_by(service_order_uuid: details[:external_reference])
          payment = budget && find_payment(budget, details[:id])

          if payment.nil?
            Rails.logger.warn("[Payments] No payment found for provider payment #{details[:id]} (ref #{details[:external_reference]})")
            Result.failure(errors: [ "Payment not found" ])
          else
            apply(budget, payment, details)
          end
        end
      end

      private

      def find_payment(budget, provider_payment_id)
        budget.payments.find_by(provider_payment_id: provider_payment_id) ||
          budget.payments.where(status: %w[pending rejected]).order(:id).last
      end

      def apply(budget, payment, details)
        case details[:status]
        when "approved"
          confirm(budget, payment, details)
        when "rejected", "cancelled"
          fail_payment(budget, payment, details)
        else
          Result.success(payload: payment)
        end
      end

      def confirm(budget, payment, details)
        return Result.success(payload: payment) if %w[approved refunded refund_failed].include?(payment.status)

        unless budget.status == "approved"
          Rails.logger.warn("[Payments] Ignoring approved payment for budget #{budget.service_order_uuid} in status #{budget.status}")
          return Result.success(payload: payment)
        end

        payment.update!(status: "approved", provider_payment_id: details[:id], failure_reason: nil,
                        raw: payment.raw.merge("provider" => details.stringify_keys))
        budget.update!(status: "paid")
        Telemetry.payment_status("approved")
        Telemetry.budget_status("paid")
        Billing::Services::EventPublisher.publish_for(
          "billing.payment_confirmed", budget,
          { payment_id: payment.id.to_s, amount_cents: payment.amount_cents, provider: "mercadopago" }
        )
        Result.success(payload: payment)
      end

      def fail_payment(budget, payment, details)
        return Result.success(payload: payment) if payment.status != "pending"

        reason = "payment_#{details[:status]}"
        payment.update!(status: "rejected", provider_payment_id: details[:id], failure_reason: reason,
                        raw: payment.raw.merge("provider" => details.stringify_keys))
        Telemetry.payment_status("rejected")
        Billing::Services::EventPublisher.publish_for("billing.payment_failed", budget,
                                                      { payment_id: payment.id.to_s, reason: reason })
        Result.success(payload: payment)
      end
    end
  end
end
