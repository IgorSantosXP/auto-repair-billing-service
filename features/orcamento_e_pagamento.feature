# language: pt
Funcionalidade: Orçamento e pagamento como participante da saga
  Como Billing Service
  Quero gerar o orçamento, colher a aprovação do cliente e cobrar via Mercado Pago
  Para que a OS só siga para execução depois de paga, e possa ser estornada se falhar

  Cenário: Orçamento aprovado pelo cliente e pago
    Quando o OS Service pede o orçamento da OS "11111111-1111-1111-1111-111111111111" com 1 serviço de 15000 centavos e 2 peças de 2500 centavos
    Então o evento "billing.budget_generated" é publicado com total de 20000 centavos
    E o cliente recebe o e-mail com o link de aprovação
    Quando o cliente aprova o orçamento pelo link do e-mail
    Então o evento "billing.budget_approved" é publicado com o link de pagamento
    Quando o Mercado Pago confirma o pagamento
    Então o evento "billing.payment_confirmed" é publicado com valor de 20000 centavos
    E o orçamento fica com status "paid"

  Cenário: Pagamento recusado
    Dado um orçamento aprovado aguardando pagamento para a OS "22222222-2222-2222-2222-222222222222"
    Quando o Mercado Pago recusa o pagamento
    Então o evento "billing.payment_failed" é publicado

  Cenário: Compensação - estorno quando a execução falha
    Dado um orçamento aprovado aguardando pagamento para a OS "33333333-3333-3333-3333-333333333333"
    E o Mercado Pago confirma o pagamento
    Quando o OS Service manda estornar o pagamento por "insufficient_stock"
    Então o evento "billing.payment_refunded" é publicado com valor de 20000 centavos
    E o orçamento fica com status "refunded"

  Cenário: Compensação - cancelamento do orçamento quando o pagamento falha
    Dado um orçamento aprovado aguardando pagamento para a OS "44444444-4444-4444-4444-444444444444"
    Quando o OS Service manda cancelar o orçamento por "payment_failed"
    Então o evento "billing.budget_cancelled" é publicado
    E o orçamento fica com status "cancelled"

  Cenário: Comando duplicado gera um único orçamento
    Quando o comando de orçamento da OS "55555555-5555-5555-5555-555555555555" é entregue 2 vezes
    Então apenas 1 evento "billing.budget_generated" é publicado
