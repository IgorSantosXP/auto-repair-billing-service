module Handlers
  class CancelBudget
    def self.call(envelope)
      Billing::UseCases::CancelBudget.call(
        service_order_uuid: envelope.service_order_uuid,
        saga_id:            envelope.saga_id,
        reason:             envelope.payload["reason"]
      )
    end
  end
end
