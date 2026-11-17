require "rails_helper"

RSpec.describe BillingMailer do
  let(:budget) { create(:budget) }

  it "renders the budget e-mail with items, total and links" do
    mail = described_class.with(budget: budget, approval_link: "http://x/approve", rejection_link: "http://x/reject").budget_generated

    expect(mail.to).to eq([ "joao@example.com" ])
    expect(mail.subject).to include(budget.service_order_uuid.split("-").first)
    html = mail.html_part.body.to_s
    expect(html).to include("Troca de óleo", "R$ 200,00", "http://x/approve", "http://x/reject")
  end

  it "renders the payment link e-mail" do
    mail = described_class.with(budget: budget, payment_url: "http://pay/me").payment_link

    expect(mail.html_part.body.to_s).to include("http://pay/me")
    expect(mail.text_part.body.to_s).to include("http://pay/me")
  end
end
