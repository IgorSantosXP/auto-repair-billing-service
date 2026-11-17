require "rails_helper"

RSpec.describe Handlers do
  let(:uuid) { SecureRandom.uuid }

  it "registers the consumed command types" do
    expect(Handlers::REGISTRY.keys).to contain_exactly("billing.generate_budget", "billing.cancel_budget", "billing.refund_payment")
  end

  describe Handlers::GenerateBudget do
    let(:envelope) do
      command_envelope("billing.generate_budget", uuid: uuid, payload: {
        "customer" => { "id" => "7", "name" => "Maria", "email" => "maria@example.com", "document" => "1" },
        "vehicle" => { "license_plate" => "AAA1A11" },
        "items" => [ { "kind" => "service", "reference_id" => "1", "name" => "Revisão", "quantity" => 2, "unit_price_cents" => 5_000 } ]
      })
    end

    it "generates the budget and emits budget_generated" do
      described_class.call(envelope)

      budget = Billing::Entities::Budget.find_by!(service_order_uuid: uuid)
      expect(budget.total_cents).to eq(10_000)
      expect(budget.saga_id).to eq(envelope.saga_id)
      expect(outbox_types).to eq([ "billing.budget_generated" ])
    end

    it "emits budget_generation_failed for a payload without items" do
      described_class.call(command_envelope("billing.generate_budget", uuid: uuid, payload: { "customer" => { "id" => "7" } }))

      expect(outbox_event("billing.budget_generation_failed").payload["reason"]).to eq("no_items")
    end

    it "is skipped on redelivery through the database idempotency" do
      idempotency = Messaging::DatabaseIdempotency.new

      expect(idempotency.once(envelope.message_id) { described_class.call(envelope) }).to be(true)
      expect(idempotency.once(envelope.message_id) { described_class.call(envelope) }).to be(false)
      expect(Messaging::OutboxMessage.count).to eq(1)
    end
  end

  describe Handlers::CancelBudget do
    it "cancels the budget" do
      budget = create(:budget)

      described_class.call(command_envelope("billing.cancel_budget", uuid: budget.service_order_uuid, payload: { "reason" => "payment_failed" }))

      expect(budget.reload.status).to eq("cancelled")
      expect(outbox_types).to eq([ "billing.budget_cancelled" ])
    end
  end

  describe Handlers::RefundPayment do
    it "refunds the approved payment" do
      budget = create(:budget, :paid)
      create(:payment, :approved, budget: budget)

      described_class.call(command_envelope("billing.refund_payment", uuid: budget.service_order_uuid, payload: { "reason" => "execution_failed" }))

      expect(budget.reload.status).to eq("refunded")
      expect(outbox_types).to eq([ "billing.payment_refunded" ])
    end

    it "emits refund_failed when the gateway fails" do
      ENV["FAKE_MERCADO_PAGO_REFUND_FAILS"] = "true"
      budget = create(:budget, :paid)
      create(:payment, :approved, budget: budget)

      described_class.call(command_envelope("billing.refund_payment", uuid: budget.service_order_uuid))

      expect(outbox_types).to eq([ "billing.refund_failed" ])
    end
  end
end
