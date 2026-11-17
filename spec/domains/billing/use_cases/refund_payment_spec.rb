require "rails_helper"

RSpec.describe Billing::UseCases::RefundPayment do
  let(:budget)  { create(:budget, :paid) }
  let!(:payment) { create(:payment, :approved, budget: budget) }

  def call
    described_class.call(service_order_uuid: budget.service_order_uuid, saga_id: budget.saga_id)
  end

  it "refunds through the gateway and publishes payment_refunded" do
    expect(call).to be_success

    expect(payment.reload.status).to eq("refunded")
    expect(payment.refund_id).to start_with("fake-refund-")
    expect(budget.reload.status).to eq("refunded")
    expect(outbox_event("billing.payment_refunded").payload).to eq(
      "payment_id" => payment.id.to_s, "refund_id" => payment.refund_id, "amount_cents" => 20_000
    )
  end

  it "marks refund_failed and publishes billing.refund_failed when the gateway raises" do
    ENV["FAKE_MERCADO_PAGO_REFUND_FAILS"] = "true"

    expect(call).to be_failure

    expect(payment.reload.status).to eq("refund_failed")
    expect(payment.failure_reason).to eq("Simulated refund failure")
    expect(budget.reload.status).to eq("paid")
    expect(outbox_event("billing.refund_failed").payload["reason"]).to eq("Simulated refund failure")
  end

  it "can retry after a failed refund" do
    payment.update!(status: "refund_failed")

    expect(call).to be_success
    expect(payment.reload.status).to eq("refunded")
  end

  it "publishes refund_failed when there is no approved payment" do
    payment.update!(status: "pending")

    expect(call).to be_failure
    expect(outbox_event("billing.refund_failed").payload["reason"]).to eq("no_approved_payment")
  end

  it "publishes refund_failed for an unknown budget" do
    uuid = SecureRandom.uuid
    described_class.call(service_order_uuid: uuid, saga_id: "saga-1")

    expect(outbox_event("billing.refund_failed").service_order_uuid).to eq(uuid)
  end

  it "republishes payment_refunded when the payment was already refunded" do
    call
    Messaging::OutboxMessage.delete_all

    expect(call).to be_success
    expect(outbox_types).to eq([ "billing.payment_refunded" ])
  end
end
