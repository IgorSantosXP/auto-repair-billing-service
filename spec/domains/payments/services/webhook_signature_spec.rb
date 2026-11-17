require "rails_helper"

RSpec.describe Payments::Services::WebhookSignature do
  let(:secret) { "whsec" }
  let(:ts)     { "1700000000" }

  def header(data_id: "ABC123", request_id: "req-1", secret: self.secret)
    "ts=#{ts},v1=#{described_class.sign(secret: secret, request_id: request_id, data_id: data_id, ts: ts)}"
  end

  def valid?(signature, data_id: "ABC123", request_id: "req-1")
    described_class.valid?(secret: secret, signature: signature, request_id: request_id, data_id: data_id)
  end

  it "matches the documented manifest, with data.id lowercased" do
    manifest = "id:abc123;request-id:req-1;ts:#{ts};"
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, manifest)

    expect(valid?("ts=#{ts},v1=#{expected}")).to be(true)
  end

  it "accepts a valid signature" do
    expect(valid?(header)).to be(true)
  end

  it "rejects a wrong secret, id or request id" do
    expect(valid?(header(secret: "other"))).to be(false)
    expect(valid?(header, data_id: "other")).to be(false)
    expect(valid?(header, request_id: "req-2")).to be(false)
  end

  it "rejects missing or malformed headers" do
    expect(valid?(nil)).to be(false)
    expect(valid?("garbage")).to be(false)
    expect(valid?("ts=#{ts}")).to be(false)
    expect(valid?("v1=abc")).to be(false)
  end

  it "rejects when the secret is blank" do
    expect(described_class.valid?(secret: "", signature: header, request_id: "req-1", data_id: "ABC123")).to be(false)
  end
end
