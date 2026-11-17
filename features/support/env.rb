ENV["RAILS_ENV"] = "test"
ENV["JWT_SECRET"] ||= "test_secret"
ENV["BILLING_PUBLIC_URL"] = "http://billing.test"
ENV["MERCADO_PAGO_MODE"] = "fake"

require "cucumber/rails"
require "rack/test"
require "webmock/cucumber"
require "factory_bot_rails"

WebMock.disable_net_connect!(allow: [ %r{127\.0\.0\.1:8126}, %r{localhost:8126} ])

ActionController::Base.allow_rescue = false
DatabaseCleaner.strategy = :truncation

World(FactoryBot::Syntax::Methods)

module BillingWorld
  include Rack::Test::Methods

  def app
    Rails.application
  end

  def json
    JSON.parse(last_response.body)
  end

  def admin_token
    Identity::Services::JwtEncoder.encode({ "sub" => "1" })
  end

  def published(type)
    Messaging::OutboxMessage.where(message_type: type).order(:id).last&.envelope
  end

  def published_types
    Messaging::OutboxMessage.order(:id).pluck(:message_type)
  end

  def deliver(type, uuid, payload = {})
    envelope = Messaging::Envelope.command(type, destination: "billing", payload: payload,
                                                 saga_id: "saga-#{uuid}", service_order_uuid: uuid)
    Messaging::DatabaseIdempotency.new.once(envelope.message_id) { Handlers::REGISTRY.fetch(type).call(envelope) }
    envelope
  end
end
World(BillingWorld)

Before do
  ActionMailer::Base.deliveries.clear
  Messaging.logger = Messaging::JsonLogger.new(StringIO.new)
end
