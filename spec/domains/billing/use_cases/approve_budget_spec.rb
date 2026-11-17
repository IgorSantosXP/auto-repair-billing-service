require "rails_helper"

RSpec.describe Billing::UseCases::ApproveBudget do
  let!(:budget) { create(:budget) }

  it "approves the budget, creates a pending payment and publishes budget_approved" do
    result = described_class.call(service_order_uuid: budget.service_order_uuid)

    expect(result).to be_success
    budget.reload
    payment = budget.payments.last
    expect(budget.status).to eq("approved")
    expect(budget.approved_at).to be_present
    expect(payment.status).to eq("pending")
    expect(payment.mode).to eq("fake")
    expect(payment.amount_cents).to eq(20_000)
    expect(payment.preference_id).to start_with("fake-pref-")
    expect(payment.payment_url).to eq("http://billing.test/api/v1/payments/#{budget.service_order_uuid}/simulate")

    event = outbox_event("billing.budget_approved")
    expect(event.payload).to eq("budget_id" => budget.uuid, "payment_url" => payment.payment_url)
    expect(event.saga_id).to eq(budget.saga_id)
  end

  it "emails the payment link" do
    described_class.call(service_order_uuid: budget.service_order_uuid)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "joao@example.com" ])
    expect(mail.text_part.body.to_s).to include("/simulate")
  end

  it "keeps the budget approved but rejects the payment when the gateway fails" do
    gateway = instance_double(Payments::Gateways::FakeMercadoPago, mode: "fake")
    allow(gateway).to receive(:create_preference).and_raise(Payments::Errors::GatewayError, "mp down")

    result = described_class.new(gateway: gateway).call(service_order_uuid: budget.service_order_uuid)

    expect(result).to be_success
    expect(budget.reload.status).to eq("approved")
    payment = budget.payments.last
    expect(payment.status).to eq("rejected")
    expect(payment.failure_reason).to eq("mp down")
    expect(outbox_types).to eq([ "billing.payment_failed" ])
    expect(outbox_event("billing.payment_failed").payload).to eq("payment_id" => payment.id.to_s, "reason" => "mp down")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "fails when the budget is not pending approval" do
    budget.update!(status: "rejected")

    result = described_class.call(service_order_uuid: budget.service_order_uuid)

    expect(result).to be_failure
    expect(result.errors.first).to include("rejected")
    expect(Messaging::OutboxMessage.count).to eq(0)
  end

  it "fails when the budget does not exist" do
    expect(described_class.call(service_order_uuid: SecureRandom.uuid).errors).to eq([ "Budget not found" ])
  end
end
