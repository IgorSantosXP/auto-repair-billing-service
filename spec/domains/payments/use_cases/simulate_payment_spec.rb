require "rails_helper"

RSpec.describe Payments::UseCases::SimulatePayment do
  let(:budget) { create(:budget) }

  before { Billing::UseCases::ApproveBudget.call(service_order_uuid: budget.service_order_uuid) }

  it "runs the webhook use case with a generated fake payment id (approved)" do
    result = described_class.call(service_order_uuid: budget.service_order_uuid, status: "approved")

    expect(result).to be_success
    payment = budget.reload.payments.last
    expect(payment.status).to eq("approved")
    expect(payment.provider_payment_id).to start_with("fake-pay-")
    expect(budget.status).to eq("paid")
    expect(outbox_types).to eq(%w[billing.budget_approved billing.payment_confirmed])
  end

  it "publishes payment_failed when rejected" do
    described_class.call(service_order_uuid: budget.service_order_uuid, status: "rejected")

    expect(budget.reload.payments.last.status).to eq("rejected")
    expect(outbox_types).to eq(%w[billing.budget_approved billing.payment_failed])
  end

  it "rejects invalid statuses" do
    expect(described_class.call(service_order_uuid: budget.service_order_uuid, status: "foo")).to be_failure
  end

  it "needs a pending payment" do
    described_class.call(service_order_uuid: budget.service_order_uuid, status: "approved")

    expect(described_class.call(service_order_uuid: budget.service_order_uuid, status: "approved")).to be_failure
    expect(described_class.call(service_order_uuid: SecureRandom.uuid, status: "approved")).to be_failure
  end
end
