require "rails_helper"

RSpec.describe Payments::Gateways::MercadoPago do
  subject(:gateway) { described_class.new }

  let(:budget) { create(:budget) }

  before { ENV["MERCADO_PAGO_ACCESS_TOKEN"] = "APP_USR-123" }

  describe "#create_preference" do
    let(:response) { { id: "pref-1", init_point: "https://mp/live", sandbox_init_point: "https://mp/sandbox" } }

    def stub_preference
      stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
        .with(headers: { "Authorization" => "Bearer #{ENV['MERCADO_PAGO_ACCESS_TOKEN']}", "X-Idempotency-Key" => /./ }) do |req|
          @body = JSON.parse(req.body)
        end
        .to_return(status: 201, body: response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "sends the preference and returns the init_point" do
      stub = stub_preference

      result = gateway.create_preference(budget)

      expect(stub).to have_been_requested
      expect(result).to eq(preference_id: "pref-1", payment_url: "https://mp/live")
      expect(@body["items"]).to eq([ {
        "id" => budget.service_order_uuid,
        "title" => "Ordem de serviço #{budget.service_order_uuid.split('-').first}",
        "quantity" => 1, "currency_id" => "BRL", "unit_price" => 200.0
      } ])
      expect(@body["external_reference"]).to eq(budget.service_order_uuid)
      expect(@body["notification_url"]).to eq("http://billing.test/webhooks/mercadopago")
      expect(@body["payer"]).to eq("email" => "joao@example.com")
      expect(@body["metadata"]).to include("service_order_uuid" => budget.service_order_uuid)
    end

    it "uses the sandbox_init_point with TEST- tokens" do
      ENV["MERCADO_PAGO_ACCESS_TOKEN"] = "TEST-123"
      stub_preference

      expect(gateway.create_preference(budget)[:payment_url]).to eq("https://mp/sandbox")
    end

    it "raises GatewayError on non-2xx and emits telemetry" do
      stub_request(:post, "https://api.mercadopago.com/checkout/preferences").to_return(status: 401, body: "{}")
      expect(Telemetry).to receive(:integration_error).with(integration: "mercadopago", reason: "http_401")

      expect { gateway.create_preference(budget) }.to raise_error(Payments::Errors::GatewayError, /401/)
    end

    it "raises GatewayError on timeouts" do
      stub_request(:post, "https://api.mercadopago.com/checkout/preferences").to_timeout

      expect { gateway.create_preference(budget) }.to raise_error(Payments::Errors::GatewayError)
    end

    it "raises GatewayError on invalid JSON" do
      stub_request(:post, "https://api.mercadopago.com/checkout/preferences").to_return(status: 200, body: "<html>")

      expect { gateway.create_preference(budget) }.to raise_error(Payments::Errors::GatewayError, /invalid JSON/)
    end
  end

  describe "#fetch_payment" do
    it "returns the normalized payment" do
      stub_request(:get, "https://api.mercadopago.com/v1/payments/123")
        .with(headers: { "Authorization" => "Bearer APP_USR-123" })
        .to_return(status: 200, body: { id: 123, status: "approved", transaction_amount: 200.0, external_reference: "ref", extra: 1 }.to_json)

      expect(gateway.fetch_payment("123")).to eq(id: "123", status: "approved", transaction_amount: 200.0, external_reference: "ref")
    end

    it "raises on 404" do
      stub_request(:get, "https://api.mercadopago.com/v1/payments/9").to_return(status: 404, body: "{}")

      expect { gateway.fetch_payment("9") }.to raise_error(Payments::Errors::GatewayError)
    end
  end

  describe "#refund" do
    let(:payment) { create(:payment, :approved, budget: budget, provider_payment_id: "123") }

    it "posts an empty body and returns the refund" do
      stub = stub_request(:post, "https://api.mercadopago.com/v1/payments/123/refunds")
             .with(body: "{}", headers: { "X-Idempotency-Key" => "refund-#{payment.id}" })
             .to_return(status: 201, body: { id: 77, amount: 200.0 }.to_json)

      expect(gateway.refund(payment)).to eq(id: "77", amount: 200.0)
      expect(stub).to have_been_requested
    end

    it "raises on errors" do
      stub_request(:post, "https://api.mercadopago.com/v1/payments/123/refunds").to_return(status: 500, body: "")

      expect { gateway.refund(payment) }.to raise_error(Payments::Errors::GatewayError)
    end
  end
end
