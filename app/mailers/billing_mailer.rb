class BillingMailer < ApplicationMailer
  def budget_generated
    @budget         = params[:budget]
    @approval_link  = params[:approval_link]
    @rejection_link = params[:rejection_link]

    mail(to: @budget.customer_email, subject: "Orçamento da ordem de serviço #{short_uuid(@budget)}")
  end

  def payment_link
    @budget      = params[:budget]
    @payment_url = params[:payment_url]

    mail(to: @budget.customer_email, subject: "Pagamento do orçamento #{short_uuid(@budget)}")
  end

  private

  def short_uuid(budget)
    budget.service_order_uuid.to_s.split("-").first
  end
end
