module Webhooks
  class MercadoPagoController < ApplicationController
    def create
      return head :unauthorized unless signature_valid?

      return render_ok("ignored") unless notification_type == "payment" && data_id.present?

      result = Payments::UseCases::ProcessPaymentNotification.call(provider_payment_id: data_id)
      render_ok(result.success? ? "processed" : "ignored")
    rescue Payments::Errors::GatewayError => e
      # Always acknowledge so Mercado Pago does not hammer us; the error is logged and metered.
      Rails.logger.error("[Webhook] Mercado Pago payment #{data_id} could not be processed: #{e.message}")
      render_ok("error")
    end

    private

    def render_ok(status)
      render json: { status: status }, status: :ok
    end

    def signature_valid?
      secret = Payments::Settings.webhook_secret

      if secret.nil?
        Rails.logger.warn("[Webhook] MERCADO_PAGO_WEBHOOK_SECRET not set, skipping signature validation")
        return true
      end

      Payments::Services::WebhookSignature.valid?(
        secret:     secret,
        signature:  request.headers["x-signature"],
        request_id: request.headers["x-request-id"],
        data_id:    data_id
      )
    end

    def notification_type
      params[:type].presence || params[:topic].presence
    end

    def data_id
      @data_id ||= (params["data.id"].presence || params.dig(:data, :id).presence).to_s
    end
  end
end
