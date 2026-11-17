module Api
  module V1
    class PaymentsController < ApplicationController
      before_action :authenticate_admin!
      before_action :require_fake_mode!

      def simulate
        result = Payments::UseCases::SimulatePayment.call(
          service_order_uuid: params[:service_order_uuid],
          status:             params[:status].to_s
        )

        if result.success?
          payment = result.payload
          render_success({ payment_status: payment.status, budget_status: payment.budget.status, payment_id: payment.id })
        else
          render_error(code: "simulation_failed", message: result.errors.first, status: :unprocessable_entity)
        end
      end

      private

      def require_fake_mode!
        render_not_found("Not available outside fake mode") unless Payments::Settings.fake?
      end
    end
  end
end
