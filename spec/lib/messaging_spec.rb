require "rails_helper"
require "datadog/statsd"

RSpec.describe "Messaging library" do
  describe Messaging::Envelope do
    it "round-trips through JSON" do
      envelope = Messaging::Envelope.event("billing.budget_generated", payload: { a: 1 }, saga_id: "s", service_order_uuid: "u")
      parsed   = Messaging::Envelope.parse(envelope.to_json)

      expect(parsed.type).to eq("billing.budget_generated")
      expect(parsed.destination).to eq("os")
      expect(parsed.source).to eq("billing-service")
      expect(parsed.correlation_id).to eq("s")
      expect(parsed.payload).to eq("a" => 1)
    end

    it "rejects unknown kinds" do
      expect { Messaging::Envelope.new("message_id" => "1", "type" => "t", "kind" => "x", "destination" => "os") }
        .to raise_error(ArgumentError)
    end
  end

  describe Messaging::Outbox do
    it "relays pending messages in order and marks them published" do
      3.times { |i| Messaging::Outbox.enqueue(Messaging::Envelope.event("t#{i}", payload: {}, saga_id: "s", service_order_uuid: "u")) }
      bus = Support::FakeBus.new

      expect(Messaging::Outbox.relay(bus: bus)).to eq(3)
      expect(bus.published.map(&:type)).to eq(%w[t0 t1 t2])
      expect(Messaging::OutboxMessage.pending.count).to eq(0)
      expect(Messaging::Outbox.relay(bus: bus)).to eq(0)
    end
  end

  describe Messaging::Bus do
    it "publishes to SNS with type and destination attributes" do
      sns = instance_double(Aws::SNS::Client)
      envelope = Messaging::Envelope.event("billing.budget_generated", payload: {}, saga_id: "s", service_order_uuid: "u")

      expect(sns).to receive(:publish).with(hash_including(
        topic_arn: "arn:topic",
        message_attributes: hash_including("destination" => { data_type: "String", string_value: "os" })
      ))
      allow(Messaging.logger).to receive(:info)

      described_class.new(client: sns, topic_arn: "arn:topic").publish(envelope)
    end
  end

  describe Messaging::Consumer do
    let(:sqs)      { instance_double(Aws::SQS::Client) }
    let(:handler)  { double("handler") }
    let(:consumer) { described_class.new(handlers: { "billing.cancel_budget" => handler }, idempotency: Messaging::DatabaseIdempotency.new, queue_url: "q", client: sqs) }
    let(:envelope) { command_envelope("billing.cancel_budget") }
    let(:message)  { Struct.new(:body, :receipt_handle).new(envelope.to_json, "rh") }

    before { allow(Messaging.logger).to receive_messages(info: nil, warn: nil, error: nil) }

    it "handles a message once and deletes it" do
      expect(handler).to receive(:call).once
      expect(sqs).to receive(:delete_message).twice

      consumer.process(message)
      consumer.process(message)
    end

    it "keeps the message on the queue when the handler fails" do
      allow(handler).to receive(:call).and_raise("boom")
      expect(sqs).not_to receive(:delete_message)

      expect(consumer.process(message)).to be(false)
      expect(Messaging::ProcessedMessage.count).to eq(0)
    end

    it "discards messages without a handler" do
      other = Struct.new(:body, :receipt_handle).new(command_envelope("unknown.type").to_json, "rh")
      expect(sqs).to receive(:delete_message)

      consumer.process(other)
    end

    it "polls the queue" do
      allow(sqs).to receive(:receive_message).and_return(double(messages: [ message ]))
      allow(sqs).to receive(:delete_message)
      allow(handler).to receive(:call)

      expect(consumer.poll_once).to eq(1)
    end
  end

  describe Messaging::Provisioner do
    it "creates topic, queues and the filtered subscription" do
      sns = instance_double(Aws::SNS::Client, create_topic: double(topic_arn: "arn:topic"))
      sqs = instance_double(Aws::SQS::Client)
      allow(sqs).to receive(:create_queue).and_return(double(queue_url: "http://q"))
      allow(sqs).to receive(:get_queue_attributes).and_return(double(attributes: { "QueueArn" => "arn:q" }))
      allow(Messaging).to receive_messages(sns: sns, sqs: sqs)
      allow(Messaging.logger).to receive(:info)

      expect(sns).to receive(:subscribe).with(hash_including(
        topic_arn: "arn:topic", protocol: "sqs",
        attributes: hash_including("RawMessageDelivery" => "true", "FilterPolicy" => { destination: [ "billing" ] }.to_json)
      ))

      result = described_class.new(destination: "billing", topic_name: "t", queue_name: "q").call
      expect(result).to eq(topic_arn: "arn:topic", queue_url: "http://q")
    ensure
      ENV.delete("EVENTS_TOPIC_ARN")
      ENV.delete("QUEUE_URL")
    end
  end

  describe Messaging::JsonLogger do
    it "writes compact JSON lines" do
      io = StringIO.new
      described_class.new(io).info("hello", saga_id: "s")

      line = JSON.parse(io.string)
      expect(line).to include("message" => "hello", "level" => "INFO", "service" => "billing-service", "saga_id" => "s")
    end
  end

  describe Messaging::Tracing do
    it "is a no-op without Datadog tracing" do
      envelope = command_envelope("billing.cancel_budget")

      expect(described_class.inject).to eq({})
      expect(described_class.log_correlation).to eq({})
      expect(described_class.continue(envelope) { :ran }).to eq(:ran)
    end
  end

  describe Telemetry do
    it "is disabled without DD_AGENT_HOST and never raises" do
      expect(described_class.client).to be_nil
      expect { described_class.budget_status("approved") }.not_to raise_error
      expect { described_class.payment_status("approved") }.not_to raise_error
      expect { described_class.integration_error(integration: "mercadopago", reason: "x") }.not_to raise_error
      expect { described_class.distribution("x", 1) }.not_to raise_error
    end

    it "emits namespaced metrics with tags when enabled" do
      statsd = instance_double(Datadog::Statsd)
      allow(described_class).to receive(:client).and_return(statsd)

      expect(statsd).to receive(:increment).with("billing.budget", tags: array_including("status:paid"))
      described_class.budget_status("paid")
    end

    it "swallows emission errors" do
      statsd = instance_double(Datadog::Statsd)
      allow(described_class).to receive(:client).and_return(statsd)
      allow(statsd).to receive(:increment).and_raise("down")

      expect { described_class.payment_status("approved") }.not_to raise_error
    end
  end
end
