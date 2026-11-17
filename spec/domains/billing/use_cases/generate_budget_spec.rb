require "rails_helper"

RSpec.describe Billing::UseCases::GenerateBudget do
  let(:uuid)     { SecureRandom.uuid }
  let(:saga_id)  { SecureRandom.uuid }
  let(:customer) { { "id" => 42, "name" => "João", "email" => "joao@example.com", "document" => "52998224725" } }
  let(:vehicle)  { { "license_plate" => "ABC1D23", "brand" => "Fiat", "model" => "Uno", "year" => 2015 } }
  let(:items) do
    [
      { "kind" => "service", "reference_id" => "1", "name" => "Troca de óleo", "quantity" => 1, "unit_price_cents" => 15_000 },
      { "kind" => "part", "reference_id" => "p1", "name" => "Filtro", "quantity" => 2, "unit_price_cents" => 2_500 }
    ]
  end

  def call(items: self.items, customer: self.customer)
    described_class.call(service_order_uuid: uuid, saga_id: saga_id, customer: customer, vehicle: vehicle, items: items)
  end

  context "with valid data" do
    it "creates the budget with items and total equal to the sum of items" do
      result = call

      expect(result).to be_success
      budget = Billing::Entities::Budget.find_by!(service_order_uuid: uuid)
      expect(budget.status).to eq("pending_approval")
      expect(budget.total_cents).to eq(20_000)
      expect(budget.items.count).to eq(2)
      expect(budget.customer_id).to eq("42")
      expect(budget.approval_token_digest).to be_present
      expect(budget.approval_token_expires_at).to be_within(1.minute).of(72.hours.from_now)
    end

    it "enqueues billing.budget_generated in the outbox" do
      call

      envelope = outbox_event("billing.budget_generated")
      budget   = Billing::Entities::Budget.find_by!(service_order_uuid: uuid)
      expect(outbox_types).to eq([ "billing.budget_generated" ])
      expect(envelope.destination).to eq("os")
      expect(envelope.saga_id).to eq(saga_id)
      expect(envelope.service_order_uuid).to eq(uuid)
      expect(envelope.payload).to eq("budget_id" => budget.uuid, "total_cents" => 20_000)
    end

    it "emails the customer with approve and reject links built with the plain token" do
      call

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "joao@example.com" ])
      body = mail.text_part.body.to_s
      token = body[/approve\?token=(\S+)/, 1]
      expect(body).to include("http://billing.test/api/v1/budgets/#{uuid}/approve?token=#{token}")
      expect(body).to include("http://billing.test/api/v1/budgets/#{uuid}/reject?token=#{token}")
      budget = Billing::Entities::Budget.find_by!(service_order_uuid: uuid)
      expect(Billing::Services::ApprovalToken.valid?(token, budget.approval_token_digest, budget.approval_token_expires_at)).to be(true)
      expect(budget.approval_token_digest).not_to eq(token)
    end

    it "does not fail when the e-mail cannot be delivered" do
      allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now).and_raise(Net::SMTPFatalError, "boom")

      expect(call).to be_success
      expect(outbox_types).to eq([ "billing.budget_generated" ])
    end

    it "is idempotent per service order" do
      call
      expect { call }.not_to change { [ Billing::Entities::Budget.count, Messaging::OutboxMessage.count ] }
    end
  end

  context "with invalid data" do
    it "publishes budget_generation_failed when there are no items" do
      result = call(items: [])

      expect(result).to be_failure
      expect(Billing::Entities::Budget.count).to eq(0)
      expect(outbox_event("billing.budget_generation_failed").payload["reason"]).to eq("no_items")
    end

    it "publishes budget_generation_failed when the total is zero" do
      call(items: [ { "kind" => "service", "name" => "Cortesia", "quantity" => 1, "unit_price_cents" => 0 } ])

      expect(outbox_event("billing.budget_generation_failed").payload["reason"]).to eq("zero_total")
    end

    it "publishes budget_generation_failed when an item is invalid" do
      call(items: [ { "kind" => "gift", "name" => "X", "quantity" => 0, "unit_price_cents" => 10 } ])

      expect(outbox_types).to eq([ "billing.budget_generation_failed" ])
      expect(outbox_event("billing.budget_generation_failed").payload["reason"]).to start_with("invalid_data")
    end

    it "publishes budget_generation_failed when the customer is missing" do
      call(customer: nil)

      expect(outbox_event("billing.budget_generation_failed").payload["reason"]).to include("Customer")
    end

    it "does not send e-mail" do
      call(items: [])

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
