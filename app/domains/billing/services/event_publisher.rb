module Billing
  module Services
    # Events always go through the transactional outbox; call inside the same
    # transaction as the state change.
    module EventPublisher
      module_function

      def publish(type, payload:, saga_id:, service_order_uuid:)
        envelope = Messaging::Envelope.event(
          type,
          payload:            payload,
          saga_id:            saga_id,
          service_order_uuid: service_order_uuid
        )
        Messaging::Outbox.enqueue(envelope)
      end

      def publish_for(type, budget, payload)
        publish(type, payload: payload, saga_id: budget.saga_id, service_order_uuid: budget.service_order_uuid)
      end
    end
  end
end
