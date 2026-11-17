require "rails_helper"

RSpec.describe Billing::UseCases::RejectBudget do
  let!(:budget) { create(:budget) }

  it "rejects the budget and publishes budget_rejected" do
    result = described_class.call(service_order_uuid: budget.service_order_uuid)

    expect(result).to be_success
    expect(budget.reload.status).to eq("rejected")
    expect(budget.rejected_at).to be_present
    expect(outbox_types).to eq([ "billing.budget_rejected" ])
    expect(outbox_event("billing.budget_rejected").payload["reason"]).to eq("rejected_by_customer")
  end

  it "fails when the budget was already decided" do
    budget.update!(status: "approved")

    expect(described_class.call(service_order_uuid: budget.service_order_uuid)).to be_failure
    expect(Messaging::OutboxMessage.count).to eq(0)
  end

  it "fails for an unknown budget" do
    expect(described_class.call(service_order_uuid: SecureRandom.uuid).errors).to eq([ "Budget not found" ])
  end
end
