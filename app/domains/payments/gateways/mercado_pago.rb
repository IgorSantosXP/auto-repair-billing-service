require "net/http"
require "json"

module Payments
  module Gateways
    class MercadoPago < Gateway
      BASE_URL = "https://api.mercadopago.com".freeze
      TIMEOUT  = 5

      def mode
        "live"
      end

      def create_preference(budget)
        body = {
          items: [
            {
              id:          budget.service_order_uuid,
              title:       "Ordem de serviço #{budget.service_order_uuid.to_s.split('-').first}",
              quantity:    1,
              currency_id: "BRL",
              unit_price:  budget.total_cents / 100.0
            }
          ],
          external_reference: budget.service_order_uuid,
          notification_url:   "#{Settings.public_url}/webhooks/mercadopago",
          payer:              { email: budget.customer_email },
          metadata:           { service_order_uuid: budget.service_order_uuid, budget_id: budget.uuid, saga_id: budget.saga_id }
        }

        response = request(:post, "/checkout/preferences", body: body, idempotency_key: "preference-#{budget.uuid}")

        {
          preference_id: response["id"],
          payment_url:   sandbox? ? response["sandbox_init_point"] : response["init_point"]
        }
      end

      def fetch_payment(payment_id)
        response = request(:get, "/v1/payments/#{URI.encode_www_form_component(payment_id.to_s)}")

        {
          id:                 response["id"].to_s,
          status:             response["status"],
          transaction_amount: response["transaction_amount"],
          external_reference: response["external_reference"]
        }
      end

      def refund(payment)
        response = request(
          :post, "/v1/payments/#{URI.encode_www_form_component(payment.provider_payment_id.to_s)}/refunds",
          body: {}, idempotency_key: "refund-#{payment.id}"
        )

        { id: response["id"].to_s, amount: response["amount"] }
      end

      private

      def sandbox?
        Settings.access_token.to_s.start_with?("TEST-")
      end

      def request(method, path, body: nil, idempotency_key: SecureRandom.uuid)
        uri  = URI.join(BASE_URL, path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT
        http.write_timeout = TIMEOUT

        req = build_request(method, uri, body, idempotency_key)
        response = http.request(req)

        unless response.is_a?(Net::HTTPSuccess)
          fail_with("Mercado Pago responded #{response.code} on #{method.to_s.upcase} #{path}", "http_#{response.code}")
        end

        response.body.to_s.empty? ? {} : JSON.parse(response.body)
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        fail_with("Mercado Pago request failed: #{e.class.name}", e.class.name)
      rescue JSON::ParserError
        fail_with("Mercado Pago returned an invalid JSON body", "invalid_json")
      end

      def build_request(method, uri, body, idempotency_key)
        klass = method == :post ? Net::HTTP::Post : Net::HTTP::Get
        req = klass.new(uri.request_uri)
        req["Authorization"]     = "Bearer #{Settings.access_token}"
        req["X-Idempotency-Key"] = idempotency_key
        req["Content-Type"]      = "application/json"
        req["Accept"]            = "application/json"
        req.body = body.to_json unless body.nil?
        req
      end

      def fail_with(message, reason)
        Telemetry.integration_error(integration: "mercadopago", reason: reason)
        raise Errors::GatewayError, message
      end
    end
  end
end
