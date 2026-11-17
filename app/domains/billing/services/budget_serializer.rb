module Billing
  module Services
    module BudgetSerializer
      module_function

      def call(budget)
        payment = budget.latest_payment

        {
          uuid:               budget.uuid,
          service_order_uuid: budget.service_order_uuid,
          saga_id:            budget.saga_id,
          status:             budget.status,
          total_cents:        budget.total_cents,
          customer: {
            id:       budget.customer_id,
            name:     budget.customer_name,
            email:    budget.customer_email,
            document: budget.customer_document
          },
          vehicle:      budget.vehicle,
          items:        budget.items.sort_by(&:id).map { |item| serialize_item(item) },
          payment:      payment && serialize_payment(payment),
          approved_at:  budget.approved_at,
          rejected_at:  budget.rejected_at,
          cancelled_at: budget.cancelled_at,
          created_at:   budget.created_at,
          updated_at:   budget.updated_at
        }
      end

      def serialize_item(item)
        {
          kind:             item.kind,
          reference_id:     item.reference_id,
          name:             item.name,
          quantity:         item.quantity,
          unit_price_cents: item.unit_price_cents,
          total_cents:      item.total_cents
        }
      end

      def serialize_payment(payment)
        {
          id:             payment.id,
          status:         payment.status,
          mode:           payment.mode,
          amount_cents:   payment.amount_cents,
          payment_url:    payment.payment_url,
          failure_reason: payment.failure_reason
        }
      end
    end
  end
end
