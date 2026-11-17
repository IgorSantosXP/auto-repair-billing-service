module Payments
  module UseCases
    # Fake mode only: stores the status the "provider" would report and then
    # runs the exact same use case the webhook runs.
    class SimulatePayment
      STATUSES = %w[approved rejected].freeze

      def self.call(...)
        new.call(...)
      end

      def call(service_order_uuid:, status:)
        return Result.failure(errors: [ "status must be one of: #{STATUSES.join(', ')}" ]) unless STATUSES.include?(status)

        budget  = Billing::Entities::Budget.find_by(service_order_uuid: service_order_uuid)
        payment = budget&.payments&.where(status: "pending")&.order(:id)&.last
        return Result.failure(errors: [ "No pending payment for this budget" ]) if payment.nil?

        fake_id = "fake-pay-#{SecureRandom.uuid}"
        payment.update!(raw: payment.raw.merge("fake_payment_id" => fake_id, "fake_status" => status))

        ProcessPaymentNotification.call(provider_payment_id: fake_id)
      end
    end
  end
end
