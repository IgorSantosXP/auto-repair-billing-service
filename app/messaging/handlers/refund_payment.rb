module Handlers
  class RefundPayment
    def self.call(envelope)
      Billing::UseCases::RefundPayment.call(
        service_order_uuid: envelope.service_order_uuid,
        saga_id:            envelope.saga_id
      )
    end
  end
end
