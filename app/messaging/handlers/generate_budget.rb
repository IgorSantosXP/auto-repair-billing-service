module Handlers
  class GenerateBudget
    def self.call(envelope)
      payload = envelope.payload

      Billing::UseCases::GenerateBudget.call(
        service_order_uuid: envelope.service_order_uuid,
        saga_id:            envelope.saga_id,
        customer:           payload["customer"],
        vehicle:            payload["vehicle"],
        items:              payload["items"]
      )
    end
  end
end
