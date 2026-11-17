require "rails_helper"

RSpec.describe Billing::UseCases::CancelBudget do
  let(:saga_id) { SecureRandom.uuid }

  def call(budget, reason: "payment_failed")
    described_class.call(service_order_uuid: budget.service_order_uuid, saga_id: saga_id, reason: reason)
  end

  %w[pending_approval approved rejected].each do |status|
    it "cancels a #{status} budget and publishes budget_cancelled" do
      budget = create(:budget, status: status)

      call(budget)

      expect(budget.reload.status).to eq("cancelled")
      expect(budget.cancelled_at).to be_present
      expect(outbox_event("billing.budget_cancelled").payload).to eq("reason" => "payment_failed")
    end
  end

  %w[paid refunded].each do |status|
    it "keeps a #{status} budget untouched" do
      budget = create(:budget, status: status)

      call(budget)

      expect(budget.reload.status).to eq(status)
      expect(budget.cancelled_at).to be_nil
    end
  end

  it "still answers the saga for an unknown budget" do
    uuid = SecureRandom.uuid
    described_class.call(service_order_uuid: uuid, saga_id: saga_id)

    envelope = outbox_event("billing.budget_cancelled")
    expect(envelope.service_order_uuid).to eq(uuid)
    expect(envelope.saga_id).to eq(saga_id)
  end

  it "does not change an already cancelled budget" do
    budget = create(:budget, status: "cancelled")

    expect { call(budget) }.not_to(change { budget.reload.updated_at })
  end
end
