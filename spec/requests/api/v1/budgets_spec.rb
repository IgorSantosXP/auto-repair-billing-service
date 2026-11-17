require "swagger_helper"

RSpec.describe "Budgets", type: :request do
  let(:budget) { create(:budget, plain_token: "plain-token") }
  let(:service_order_uuid) { budget.service_order_uuid }
  let(:Authorization) { "Bearer #{admin_token}" }

  path "/api/v1/budgets" do
    get "Lists budgets (admin)" do
      tags "Budgets"
      security [ bearerAuth: [] ]
      produces "application/json"
      parameter name: :page,     in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :status,   in: :query, type: :string,  required: false

      response "200", "paginated list" do
        let(:per_page) { 2 }
        before { create_list(:budget, 3) }

        run_test! do |response|
          expect(JSON.parse(response.body).size).to eq(2)
          expect(response.headers["X-Total-Count"]).to eq("3")
          expect(response.headers["X-Per-Page"]).to eq("2")
          expect(response.headers["X-Page"]).to eq("1")
        end
      end

      response "200", "filtered by status" do
        let(:status) { "paid" }
        before { create(:budget); create(:budget, :paid) }

        run_test! { |response| expect(JSON.parse(response.body).map { |b| b["status"] }).to eq([ "paid" ]) }
      end

      response "401", "missing or invalid token" do
        let(:Authorization) { "Bearer #{customer_token(sub: '1')}" }
        run_test!
      end
    end
  end

  path "/api/v1/budgets/{service_order_uuid}" do
    parameter name: :service_order_uuid, in: :path, type: :string, format: :uuid
    parameter name: :token, in: :query, type: :string, required: false, description: "Token do link enviado por e-mail"

    get "Shows a budget (admin, owning customer or e-mail token)" do
      tags "Budgets"
      security [ bearerAuth: [] ]
      produces "application/json"

      response "200", "admin" do
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["service_order_uuid"]).to eq(service_order_uuid)
          expect(body["total_cents"]).to eq(20_000)
          expect(body["items"].size).to eq(2)
          expect(body).not_to have_key("approval_token_digest")
        end
      end

      response "200", "owning customer" do
        let(:Authorization) { "Bearer #{customer_token(sub: '42')}" }
        run_test!
      end

      response "200", "valid e-mail token" do
        let(:Authorization) { nil }
        let(:token) { "plain-token" }
        run_test!
      end

      response "401", "invalid e-mail token" do
        let(:Authorization) { nil }
        let(:token) { "wrong" }
        run_test!
      end

      response "401", "no credentials" do
        let(:Authorization) { nil }
        run_test!
      end

      response "403", "another customer" do
        let(:Authorization) { "Bearer #{customer_token(sub: '999')}" }
        run_test!
      end

      response "404", "unknown budget" do
        let(:service_order_uuid) { SecureRandom.uuid }
        run_test!
      end
    end
  end

  %w[approve reject].each do |action|
    path "/api/v1/budgets/{service_order_uuid}/#{action}" do
      parameter name: :service_order_uuid, in: :path, type: :string, format: :uuid
      parameter name: :token, in: :query, type: :string, required: false
      let(:Authorization) { nil }
      let(:token) { "plain-token" }

      [ :post, :get ].each do |verb|
        public_send(verb, "#{action.capitalize}s a budget (#{verb.to_s.upcase})") do
          tags "Budgets"
          security [ bearerAuth: [] ]
          produces "application/json"

          response "200", "#{action} with e-mail token" do
            run_test! do |response|
              body = JSON.parse(response.body)
              expected = action == "approve" ? "approved" : "rejected"
              expect(body["status"]).to eq(expected)
              expect(budget.reload.status).to eq(expected)
              if action == "approve"
                expect(body["payment_url"]).to eq("http://billing.test/api/v1/payments/#{service_order_uuid}/simulate")
                expect(outbox_types).to eq([ "billing.budget_approved" ])
              else
                expect(outbox_types).to eq([ "billing.budget_rejected" ])
              end
            end
          end

          response "200", "#{action} with the owning customer's JWT" do
            let(:Authorization) { "Bearer #{customer_token(sub: '42')}" }
            let(:token) { nil }
            run_test!
          end

          response "401", "invalid token" do
            let(:token) { "bad" }
            run_test! { expect(budget.reload.status).to eq("pending_approval") }
          end

          response "401", "admin token is not accepted" do
            let(:Authorization) { "Bearer #{admin_token}" }
            let(:token) { nil }
            run_test!
          end

          response "403", "another customer" do
            let(:Authorization) { "Bearer #{customer_token(sub: '1')}" }
            let(:token) { nil }
            run_test!
          end

          response "404", "unknown budget" do
            let(:service_order_uuid) { SecureRandom.uuid }
            run_test!
          end

          response "422", "budget is not pending approval" do
            before { budget.update!(status: "cancelled") }
            run_test!
          end
        end
      end
    end
  end

  describe "approve when the gateway fails" do
    it "answers 200 with the payment rejected and publishes payment_failed" do
      allow_any_instance_of(Payments::Gateways::FakeMercadoPago).to receive(:create_preference)
        .and_raise(Payments::Errors::GatewayError, "mp down")

      post "/api/v1/budgets/#{budget.service_order_uuid}/approve", params: { token: "plain-token" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("status" => "approved", "payment_status" => "rejected", "payment_url" => nil)
      expect(outbox_types).to eq([ "billing.payment_failed" ])
    end
  end
end
