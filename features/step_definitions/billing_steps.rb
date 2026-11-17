def budget_payload(service_cents: 15_000, part_cents: 2_500, parts: 2)
  {
    "customer" => { "id" => "42", "name" => "Maria Silva", "email" => "maria@example.com", "document" => "52998224725" },
    "vehicle"  => { "license_plate" => "ABC1D23", "brand" => "Fiat", "model" => "Uno", "year" => 2018 },
    "items"    => [
      { "kind" => "service", "reference_id" => "1", "name" => "Revisão", "quantity" => 1, "unit_price_cents" => service_cents },
      { "kind" => "part", "reference_id" => "oleo-5w30", "name" => "Óleo 5W30", "quantity" => parts, "unit_price_cents" => part_cents }
    ]
  }
end

def approval_token
  body = ActionMailer::Base.deliveries.map { |mail| mail.text_part&.decoded || mail.body.decoded }.join
  body[/token=([\w-]+)/, 1] || raise("approval link not found in the email")
end

def simulate_payment(status)
  header "Authorization", "Bearer #{admin_token}"
  header "Content-Type", "application/json"
  post "/api/v1/payments/#{@uuid}/simulate", { status: status }.to_json
  expect(last_response.status).to eq(200), last_response.body
end

Quando("o OS Service pede o orçamento da OS {string} com {int} serviço de {int} centavos e {int} peças de {int} centavos") do |uuid, _services, service_cents, parts, part_cents|
  @uuid = uuid
  deliver("billing.generate_budget", uuid, budget_payload(service_cents: service_cents, part_cents: part_cents, parts: parts))
end

Quando("o comando de orçamento da OS {string} é entregue {int} vezes") do |uuid, times|
  envelope = Messaging::Envelope.command("billing.generate_budget", destination: "billing", payload: budget_payload,
                                                                   saga_id: "saga", service_order_uuid: uuid)
  times.times do
    Messaging::DatabaseIdempotency.new.once(envelope.message_id) { Handlers::REGISTRY.fetch(envelope.type).call(envelope) }
  end
end

Dado("um orçamento aprovado aguardando pagamento para a OS {string}") do |uuid|
  @uuid = uuid
  deliver("billing.generate_budget", uuid, budget_payload)
  post "/api/v1/budgets/#{uuid}/approve", token: approval_token
  expect(json["payment_status"]).to eq("pending")
end

Quando("o cliente aprova o orçamento pelo link do e-mail") do
  post "/api/v1/budgets/#{@uuid}/approve", token: approval_token
  expect(last_response.status).to eq(200), last_response.body
end

Quando("o Mercado Pago confirma o pagamento") do
  simulate_payment("approved")
end

Quando("o Mercado Pago recusa o pagamento") do
  simulate_payment("rejected")
end

Quando("o OS Service manda estornar o pagamento por {string}") do |reason|
  deliver("billing.refund_payment", @uuid, "reason" => reason)
end

Quando("o OS Service manda cancelar o orçamento por {string}") do |reason|
  deliver("billing.cancel_budget", @uuid, "reason" => reason)
end

Então("o evento {string} é publicado com total de {int} centavos") do |type, total|
  expect(published(type).payload["total_cents"]).to eq(total)
end

Então("o evento {string} é publicado com valor de {int} centavos") do |type, amount|
  expect(published(type).payload["amount_cents"]).to eq(amount)
end

Então("o evento {string} é publicado com o link de pagamento") do |type|
  expect(published(type).payload["payment_url"]).to be_present
end

Então("o evento {string} é publicado") do |type|
  expect(published_types).to include(type)
end

Então("apenas {int} evento {string} é publicado") do |count, type|
  expect(published_types.count(type)).to eq(count)
end

Então("o cliente recebe o e-mail com o link de aprovação") do
  mail = ActionMailer::Base.deliveries.last
  expect(mail.to).to eq([ "maria@example.com" ])
  expect(approval_token).to be_present
end

Então("o orçamento fica com status {string}") do |status|
  expect(Billing::Entities::Budget.find_by!(service_order_uuid: @uuid).status).to eq(status)
end
