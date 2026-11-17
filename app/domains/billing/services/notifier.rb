module Billing
  module Services
    # E-mail must never break the saga: any delivery error is logged and swallowed.
    module Notifier
      module_function

      def budget_generated(budget, approval_link:, rejection_link:)
        deliver(:budget_generated, budget: budget, approval_link: approval_link, rejection_link: rejection_link)
      end

      def payment_link(budget, payment_url:)
        deliver(:payment_link, budget: budget, payment_url: payment_url)
      end

      def deliver(mail, **params)
        budget = params.fetch(:budget)
        return false if budget.customer_email.blank?

        BillingMailer.with(**params).public_send(mail).deliver_now
        true
      rescue StandardError => e
        Rails.logger.error("[Billing] Failed to send #{mail} e-mail for #{budget.service_order_uuid}: #{e.class.name} #{e.message}")
        false
      end
    end
  end
end
