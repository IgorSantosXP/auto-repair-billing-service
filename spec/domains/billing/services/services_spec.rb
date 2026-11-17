require "rails_helper"

RSpec.describe Billing::Services::ApprovalToken do
  it "generates a plain token whose SHA256 digest validates it" do
    token = described_class.generate

    expect(token[:digest]).to eq(Digest::SHA256.hexdigest(token[:plain]))
    expect(token[:expires_at]).to be_within(1.minute).of(72.hours.from_now)
    expect(described_class.valid?(token[:plain], token[:digest], token[:expires_at])).to be(true)
  end

  it "rejects wrong, blank and expired tokens" do
    token = described_class.generate

    expect(described_class.valid?("other", token[:digest], token[:expires_at])).to be(false)
    expect(described_class.valid?(nil, token[:digest], token[:expires_at])).to be(false)
    expect(described_class.valid?(token[:plain], token[:digest], 1.minute.ago)).to be(false)
    expect(described_class.valid?(token[:plain], nil, nil)).to be(false)
  end
end

RSpec.describe Billing::Services::Notifier do
  it "skips budgets without e-mail" do
    budget = build(:budget, customer_email: nil)

    expect(described_class.payment_link(budget, payment_url: "http://x")).to be(false)
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end

RSpec.describe Billing::Services::BudgetSerializer do
  it "serializes the budget with items and the latest payment" do
    budget = create(:budget)
    create(:payment, budget: budget)

    data = described_class.call(budget.reload)

    expect(data[:status]).to eq("pending_approval")
    expect(data[:items].size).to eq(2)
    expect(data[:payment][:status]).to eq("pending")
    expect(data).not_to have_key(:approval_token_digest)
  end
end

RSpec.describe Billing::Queries::ListBudgets do
  it "paginates and filters by status" do
    create_list(:budget, 3)
    create(:budget, status: "paid")

    result = described_class.call(page: 1, per_page: 2)
    expect(result.payload[:total]).to eq(4)
    expect(result.payload[:budgets].size).to eq(2)

    expect(described_class.call(page: 1, per_page: 10, status: "paid").payload[:total]).to eq(1)
  end
end

RSpec.describe "Budget model" do
  it "enforces the status check constraint in the database" do
    budget = create(:budget)

    expect { budget.update_column(:status, "bogus") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "validates fields" do
    budget = build(:budget, total_cents: -1, status: "x")
    budget.validate

    expect(budget.errors.attribute_names).to include(:status)
  end
end
