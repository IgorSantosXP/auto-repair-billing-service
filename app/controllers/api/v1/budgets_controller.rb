module Api
  module V1
    class BudgetsController < ApplicationController
      before_action :authenticate_admin!, only: :index
      before_action :load_budget, only: %i[show approve reject]
      before_action :authorize_budget_access!, only: %i[show approve reject]

      def index
        pagination = pagination_params
        result = Billing::Queries::ListBudgets.call(**pagination, status: params[:status].presence)

        set_pagination_headers(result.payload[:total], pagination[:page], pagination[:per_page])
        render_success(result.payload[:budgets].map { |budget| Billing::Services::BudgetSerializer.call(budget) })
      end

      def show
        render_success(Billing::Services::BudgetSerializer.call(@budget))
      end

      def approve
        result = Billing::UseCases::ApproveBudget.call(service_order_uuid: @budget.service_order_uuid)

        if result.success?
          payment = result.payload[:payment]
          render_success({
            message:        payment.status == "pending" ? "Budget approved" : "Budget approved but the payment could not be created",
            status:         result.payload[:budget].status,
            payment_status: payment.status,
            payment_url:    payment.payment_url
          })
        else
          render_error(code: "approval_failed", message: result.errors.first, status: :unprocessable_entity)
        end
      end

      def reject
        result = Billing::UseCases::RejectBudget.call(service_order_uuid: @budget.service_order_uuid)

        if result.success?
          render_success({ message: "Budget rejected", status: result.payload.status })
        else
          render_error(code: "rejection_failed", message: result.errors.first, status: :unprocessable_entity)
        end
      end

      private

      def load_budget
        @budget = Billing::Entities::Budget.includes(:items, :payments).find_by(service_order_uuid: params[:service_order_uuid])
        render_not_found("Budget not found") if @budget.nil?
      end

      # Access is granted by (in order): the e-mail link token, the owning customer's JWT,
      # or (read-only) an admin JWT.
      def authorize_budget_access!
        return authorize_token! if params[:token].present?

        if action_name == "show" && decode_token(Identity::Services::JwtEncoder::ADMIN_AUDIENCE)
          return
        end

        payload = decode_token(Identity::Services::JwtEncoder::CUSTOMER_AUDIENCE)
        return render_unauthorized("Invalid or expired token") if payload.nil?

        return if payload["sub"].to_s == @budget.customer_id.to_s

        render_error(code: "forbidden", message: "This budget belongs to another customer", status: :forbidden)
      end

      def authorize_token!
        return if Billing::Services::ApprovalToken.valid?(params[:token], @budget.approval_token_digest, @budget.approval_token_expires_at)

        render_unauthorized("Invalid or expired approval token")
      end
    end
  end
end
