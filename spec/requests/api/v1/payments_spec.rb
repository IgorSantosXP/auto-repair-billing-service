require "swagger_helper"

RSpec.describe "Payments simulation", type: :request do
  let(:budget) { create(:budget) }
  let(:service_order_uuid) { budget.service_order_uuid }
  let(:Authorization) { "Bearer #{admin_token}" }

  before { Billing::UseCases::ApproveBudget.call(service_order_uuid: budget.service_order_uuid) }

  path "/api/v1/payments/{service_order_uuid}/simulate" do
    parameter name: :service_order_uuid, in: :path, type: :string, format: :uuid

    post "Simulates the payment provider notification (fake mode only, admin)" do
      tags "Payments"
      security [ bearerAuth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { status: { type: :string, enum: %w[approved rejected] } },
        required: %w[status]
      }

      response "200", "approved" do
        let(:body) { { status: "approved" } }
        run_test! do |response|
          expect(JSON.parse(response.body)).to include("payment_status" => "approved", "budget_status" => "paid")
          expect(outbox_types).to eq(%w[billing.budget_approved billing.payment_confirmed])
        end
      end

      response "200", "rejected" do
        let(:body) { { status: "rejected" } }
        run_test! do |response|
          expect(JSON.parse(response.body)).to include("payment_status" => "rejected")
          expect(outbox_types).to eq(%w[billing.budget_approved billing.payment_failed])
        end
      end

      response "401", "without admin token" do
        let(:Authorization) { "Bearer #{customer_token(sub: '42')}" }
        let(:body) { { status: "approved" } }
        run_test!
      end

      response "404", "outside fake mode" do
        let(:body) { { status: "approved" } }
        before { ENV["MERCADO_PAGO_MODE"] = "live" }
        run_test!
      end

      response "422", "invalid status" do
        let(:body) { { status: "foo" } }
        run_test!
      end
    end
  end
end
