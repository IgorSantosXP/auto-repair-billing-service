require "swagger_helper"

RSpec.describe "Mercado Pago webhook", type: :request do
  let(:budget)  { create(:budget, :approved) }
  let!(:payment) { create(:payment, budget: budget) }
  let(:payload) { { type: "payment", action: "payment.updated", data: { id: "123" } } }

  def stub_mp_payment(status)
    stub_request(:get, "https://api.mercadopago.com/v1/payments/123")
      .to_return(status: 200, body: { id: 123, status: status, transaction_amount: 200.0, external_reference: budget.service_order_uuid }.to_json)
  end

  before { ENV["MERCADO_PAGO_MODE"] = "live" }

  path "/webhooks/mercadopago" do
    post "Receives Mercado Pago payment notifications" do
      tags "Webhooks"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, example: "payment" },
          data: { type: :object, properties: { id: { type: :string } } }
        }
      }

      response "200", "approved payment without a configured secret" do
        let(:body) { payload }
        before { stub_mp_payment("approved") }

        run_test! do
          expect(budget.reload.status).to eq("paid")
          expect(payment.reload.status).to eq("approved")
          expect(outbox_types).to eq([ "billing.payment_confirmed" ])
        end
      end

      response "200", "rejected payment" do
        let(:body) { payload }
        before { stub_mp_payment("rejected") }

        run_test! do
          expect(payment.reload.status).to eq("rejected")
          expect(outbox_types).to eq([ "billing.payment_failed" ])
        end
      end

      response "200", "non-payment notifications are ignored" do
        let(:body) { { type: "merchant_order", data: { id: "9" } } }
        run_test! { expect(Messaging::OutboxMessage.count).to eq(0) }
      end

      response "200", "gateway failures are acknowledged" do
        let(:body) { payload }
        before { stub_request(:get, "https://api.mercadopago.com/v1/payments/123").to_return(status: 500, body: "") }
        run_test! { expect(Messaging::OutboxMessage.count).to eq(0) }
      end

      response "200", "duplicate notifications do nothing" do
        let(:body) { payload }
        before do
          stub_mp_payment("approved")
          post "/webhooks/mercadopago", params: payload, as: :json
        end

        run_test! { expect(outbox_types).to eq([ "billing.payment_confirmed" ]) }
      end
    end
  end

  describe "signature validation" do
    let(:secret) { "whsec" }
    let(:ts)     { "1700000000" }
    let(:valid_signature) do
      "ts=#{ts},v1=#{Payments::Services::WebhookSignature.sign(secret: secret, request_id: 'req-1', data_id: '123', ts: ts)}"
    end

    before do
      ENV["MERCADO_PAGO_WEBHOOK_SECRET"] = secret
      stub_mp_payment("approved")
    end

    it "accepts a valid signature (data.id from the query string)" do
      post "/webhooks/mercadopago?data.id=123&type=payment",
           headers: { "x-signature" => valid_signature, "x-request-id" => "req-1" }

      expect(response).to have_http_status(:ok)
      expect(budget.reload.status).to eq("paid")
    end

    it "accepts a valid signature (data.id from the body)" do
      post "/webhooks/mercadopago", params: payload, as: :json,
           headers: { "x-signature" => valid_signature, "x-request-id" => "req-1" }

      expect(response).to have_http_status(:ok)
    end

    it "answers 401 on an invalid signature" do
      post "/webhooks/mercadopago", params: payload, as: :json,
           headers: { "x-signature" => "ts=#{ts},v1=deadbeef", "x-request-id" => "req-1" }

      expect(response).to have_http_status(:unauthorized)
      expect(budget.reload.status).to eq("approved")
    end

    it "answers 401 when the signature is missing" do
      post "/webhooks/mercadopago", params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
