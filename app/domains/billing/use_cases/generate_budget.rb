module Billing
  module UseCases
    class GenerateBudget
      def self.call(...)
        new.call(...)
      end

      def call(service_order_uuid:, saga_id:, customer:, vehicle:, items:)
        existing = Entities::Budget.find_by(service_order_uuid: service_order_uuid)
        if existing
          Rails.logger.info("[Billing] Budget for #{service_order_uuid} already exists, ignoring")
          return Result.success(payload: existing)
        end

        token  = Services::ApprovalToken.generate
        budget = nil
        failure_reason = nil

        ActiveRecord::Base.transaction do
          budget = build_budget(service_order_uuid, saga_id, customer, vehicle, items, token)
          failure_reason = validation_failure(budget)

          if failure_reason
            Services::EventPublisher.publish("billing.budget_generation_failed",
                                             payload: { reason: failure_reason },
                                             saga_id: saga_id, service_order_uuid: service_order_uuid)
          else
            budget.save!
            Services::EventPublisher.publish_for("billing.budget_generated", budget,
                                                 { budget_id: budget.uuid, total_cents: budget.total_cents })
          end
        end

        if failure_reason
          Telemetry.budget_status("generation_failed")
          return Result.failure(errors: [ failure_reason ])
        end

        Telemetry.budget_status(budget.status)
        notify(budget, token[:plain])
        Result.success(payload: budget)
      end

      private

      def build_budget(service_order_uuid, saga_id, customer, vehicle, items, token)
        customer = (customer || {}).with_indifferent_access
        budget = Entities::Budget.new(
          service_order_uuid:        service_order_uuid,
          saga_id:                   saga_id,
          customer_id:               customer[:id].to_s.presence,
          customer_name:             customer[:name],
          customer_email:            customer[:email],
          customer_document:         customer[:document],
          vehicle:                   vehicle.is_a?(Hash) ? vehicle : {},
          status:                    "pending_approval",
          approval_token_digest:     token[:digest],
          approval_token_expires_at: token[:expires_at]
        )

        Array(items).each do |item|
          item = item.respond_to?(:to_h) ? item.to_h.with_indifferent_access : {}
          budget.items.build(
            kind:             item[:kind],
            reference_id:     item[:reference_id]&.to_s,
            name:             item[:name],
            quantity:         item[:quantity],
            unit_price_cents: item[:unit_price_cents]
          )
        end
        budget.recalculate_total
        budget
      end

      # Returns a short reason when the budget cannot be created, nil otherwise.
      def validation_failure(budget)
        return "no_items" if budget.items.empty?
        return "invalid_data: #{budget.errors.full_messages.to_sentence}" unless budget.valid?
        return "zero_total" if budget.total_cents.zero?

        nil
      end

      def notify(budget, plain_token)
        base = Payments::Settings.public_url
        path = "/api/v1/budgets/#{budget.service_order_uuid}"
        Services::Notifier.budget_generated(
          budget,
          approval_link: "#{base}#{path}/approve?token=#{plain_token}",
          rejection_link: "#{base}#{path}/reject?token=#{plain_token}"
        )
      end
    end
  end
end
