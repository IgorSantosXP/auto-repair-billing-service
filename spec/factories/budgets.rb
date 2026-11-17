FactoryBot.define do
  factory :budget, class: "Billing::Entities::Budget" do
    service_order_uuid { SecureRandom.uuid }
    saga_id { SecureRandom.uuid }
    customer_id { "42" }
    customer_name { "João da Silva" }
    customer_email { "joao@example.com" }
    customer_document { "52998224725" }
    vehicle { { "license_plate" => "ABC1D23", "brand" => "Fiat", "model" => "Uno", "year" => 2015 } }
    status { "pending_approval" }
    transient { plain_token { "plain-token" } }

    after(:build) do |budget, evaluator|
      if budget.items.empty?
        budget.items.build(kind: "service", reference_id: "1", name: "Troca de óleo", quantity: 1, unit_price_cents: 15_000)
        budget.items.build(kind: "part", reference_id: "p1", name: "Filtro de óleo", quantity: 2, unit_price_cents: 2_500)
      end
      budget.recalculate_total
      budget.approval_token_digest ||= Digest::SHA256.hexdigest(evaluator.plain_token)
      budget.approval_token_expires_at ||= 72.hours.from_now
    end

    trait(:approved) { status { "approved" } }
    trait(:paid) { status { "paid" } }
  end

  factory :payment, class: "Payments::Entities::Payment" do
    association :budget
    provider { "mercadopago" }
    mode { "fake" }
    status { "pending" }
    amount_cents { budget.total_cents }
    preference_id { "fake-pref-1" }
    payment_url { "http://billing.test/api/v1/payments/x/simulate" }

    trait(:approved) do
      status { "approved" }
      sequence(:provider_payment_id) { |n| "pay-#{n}" }
    end
  end
end
