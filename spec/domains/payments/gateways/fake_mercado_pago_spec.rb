require "rails_helper"

RSpec.describe Payments::Gateways::FakeMercadoPago do
  subject(:gateway) { described_class.new }

  let(:budget) { create(:budget) }

  it "creates deterministic offline preferences" do
    result = gateway.create_preference(budget)

    expect(result[:preference_id]).to match(/\Afake-pref-[0-9a-f-]{36}\z/)
    expect(result[:payment_url]).to eq("http://billing.test/api/v1/payments/#{budget.service_order_uuid}/simulate")
  end

  it "returns the status stored by the simulation" do
    payment = create(:payment, budget: budget, raw: { "fake_payment_id" => "fake-pay-1", "fake_status" => "approved" })

    expect(gateway.fetch_payment("fake-pay-1")).to eq(
      id: "fake-pay-1", status: "approved", transaction_amount: payment.amount_cents / 100.0,
      external_reference: budget.service_order_uuid
    )
  end

  it "raises for unknown payments" do
    expect { gateway.fetch_payment("nope") }.to raise_error(Payments::Errors::GatewayError)
  end

  it "refunds with a fake refund id" do
    payment = create(:payment, :approved, budget: budget)

    expect(gateway.refund(payment)[:id]).to start_with("fake-refund-")
  end

  it "raises on refund when FAKE_MERCADO_PAGO_REFUND_FAILS=true" do
    ENV["FAKE_MERCADO_PAGO_REFUND_FAILS"] = "true"

    expect { gateway.refund(create(:payment, :approved, budget: budget)) }.to raise_error(Payments::Errors::GatewayError)
  end
end

RSpec.describe Payments::Gateways::Factory do
  it "builds the adapter for the configured mode" do
    expect(described_class.build).to be_a(Payments::Gateways::FakeMercadoPago)
    expect(described_class.build(mode: "live")).to be_a(Payments::Gateways::MercadoPago)
    expect { described_class.build(mode: "x") }.to raise_error(ArgumentError)
  end

  it "defaults the base specification" do
    expect(Payments::Settings.mode).to eq("fake")
    expect(Payments::Gateways::Gateway.new).to respond_to(:create_preference)
    expect { Payments::Gateways::Gateway.new.create_preference(nil) }.to raise_error(NotImplementedError)
    expect { Payments::Gateways::Gateway.new.fetch_payment(nil) }.to raise_error(NotImplementedError)
    expect { Payments::Gateways::Gateway.new.refund(nil) }.to raise_error(NotImplementedError)
    expect { Payments::Gateways::Gateway.new.mode }.to raise_error(NotImplementedError)
  end
end
