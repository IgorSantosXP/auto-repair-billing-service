module Payments
  module Gateways
    # Deterministic, offline adapter. The "provider" state lives in the payment's
    # `raw` column, written by Payments::UseCases::SimulatePayment, so the API and
    # worker processes see the same data.
    class FakeMercadoPago < Gateway
      def mode
        "fake"
      end

      def create_preference(budget)
        {
          preference_id: "fake-pref-#{SecureRandom.uuid}",
          payment_url:   "#{Settings.public_url}/api/v1/payments/#{budget.service_order_uuid}/simulate"
        }
      end

      def fetch_payment(payment_id)
        payment = Entities::Payment.where("raw->>'fake_payment_id' = ?", payment_id.to_s).first
        raise Errors::GatewayError, "Fake payment #{payment_id} not found" if payment.nil?

        {
          id:                 payment_id.to_s,
          status:             payment.raw["fake_status"],
          transaction_amount: payment.amount_cents / 100.0,
          external_reference: payment.budget.service_order_uuid
        }
      end

      def refund(payment)
        if ENV["FAKE_MERCADO_PAGO_REFUND_FAILS"] == "true"
          Telemetry.integration_error(integration: "mercadopago", reason: "fake_refund_failure")
          raise Errors::GatewayError, "Simulated refund failure"
        end

        { id: "fake-refund-#{SecureRandom.uuid}", amount: payment.amount_cents / 100.0 }
      end
    end
  end
end
