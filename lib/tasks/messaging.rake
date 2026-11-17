namespace :messaging do
  desc "Relays the outbox and consumes the billing queue"
  task work: :environment do
    if ENV["MESSAGING_AUTO_PROVISION"] == "true"
      Messaging::Provisioner.new(
        destination: "billing",
        topic_name:  ENV.fetch("EVENTS_TOPIC_NAME", "auto-repair-local-events"),
        queue_name:  ENV.fetch("QUEUE_NAME", "auto-repair-local-billing")
      ).call
    end

    consumer = Messaging::Consumer.new(handlers: Handlers::REGISTRY, idempotency: Messaging::DatabaseIdempotency.new)
    Messaging::Worker.new(consumer: consumer).start
  end
end
