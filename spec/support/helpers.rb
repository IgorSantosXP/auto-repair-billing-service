module Support
  module Helpers
    def admin_token(sub: "1")
      Identity::Services::JwtEncoder.encode({ "sub" => sub })
    end

    def customer_token(sub:)
      Identity::Services::JwtEncoder.encode({ "sub" => sub }, audience: Identity::Services::JwtEncoder::CUSTOMER_AUDIENCE)
    end

    def outbox_types
      Messaging::OutboxMessage.order(:id).pluck(:message_type)
    end

    def outbox_event(type)
      Messaging::OutboxMessage.where(message_type: type).order(:id).last&.envelope
    end

    def command_envelope(type, uuid: SecureRandom.uuid, saga_id: SecureRandom.uuid, payload: {})
      Messaging::Envelope.command(type, destination: "billing", payload: payload, saga_id: saga_id, service_order_uuid: uuid)
    end
  end
end

RSpec.configure do |config|
  config.include Support::Helpers
end
