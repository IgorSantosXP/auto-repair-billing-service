require "rails_helper"

RSpec.describe Payments::UseCases::ProcessPaymentNotification do
  let(:budget)  { create(:budget, :approved) }
  let!(:payment) { create(:payment, budget: budget) }
  let(:gateway) { instance_double(Payments::Gateways::MercadoPago) }

  def details(status, id: "mp-1")
    { id: id, status: status, transaction_amount: 200.0, external_reference: budget.service_order_uuid }
  end

  def call(status, id: "mp-1")
    allow(gateway).to receive(:fetch_payment).with(id).and_return(details(status, id: id))
    described_class.new(gateway: gateway).call(provider_payment_id: id)
  end

  it "confirms an approved payment" do
    expect(call("approved")).to be_success

    expect(payment.reload.status).to eq("approved")
    expect(payment.provider_payment_id).to eq("mp-1")
    expect(budget.reload.status).to eq("paid")
    expect(outbox_event("billing.payment_confirmed").payload).to eq(
      "payment_id" => payment.id.to_s, "amount_cents" => 20_000, "provider" => "mercadopago"
    )
  end

  it "is idempotent for repeated approved notifications" do
    call("approved")

    expect { call("approved") }.not_to change(Messaging::OutboxMessage, :count)
    expect(budget.reload.status).to eq("paid")
  end

  %w[rejected cancelled].each do |status|
    it "fails the payment when the provider reports #{status}" do
      expect(call(status)).to be_success

      expect(payment.reload.status).to eq("rejected")
      expect(payment.failure_reason).to eq("payment_#{status}")
      expect(budget.reload.status).to eq("approved")
      expect(outbox_event("billing.payment_failed").payload).to eq(
        "payment_id" => payment.id.to_s, "reason" => "payment_#{status}"
      )
    end
  end

  it "is idempotent for repeated rejected notifications" do
    call("rejected")

    expect { call("rejected") }.not_to change(Messaging::OutboxMessage, :count)
  end

  it "accepts an approved retry after a rejected attempt" do
    call("rejected")
    call("approved", id: "mp-2")

    expect(payment.reload.status).to eq("approved")
    expect(outbox_types).to eq(%w[billing.payment_failed billing.payment_confirmed])
  end

  it "does not downgrade an approved payment on a late rejection" do
    call("approved")

    expect { call("rejected", id: "mp-1") }.not_to change(Messaging::OutboxMessage, :count)
    expect(payment.reload.status).to eq("approved")
  end

  it "ignores approved payments for budgets that are no longer approved" do
    budget.update!(status: "cancelled")

    expect { call("approved") }.not_to change(Messaging::OutboxMessage, :count)
    expect(payment.reload.status).to eq("pending")
  end

  it "ignores intermediate statuses" do
    expect { call("in_process") }.not_to change(Messaging::OutboxMessage, :count)
  end

  it "fails when there is no budget for the external reference" do
    allow(gateway).to receive(:fetch_payment).and_return(details("approved").merge(external_reference: SecureRandom.uuid))

    result = described_class.new(gateway: gateway).call(provider_payment_id: "mp-1")

    expect(result).to be_failure
    expect(Messaging::OutboxMessage.count).to eq(0)
  end

  it "propagates gateway errors" do
    allow(gateway).to receive(:fetch_payment).and_raise(Payments::Errors::GatewayError, "down")

    expect { described_class.new(gateway: gateway).call(provider_payment_id: "mp-1") }
      .to raise_error(Payments::Errors::GatewayError)
  end
end
