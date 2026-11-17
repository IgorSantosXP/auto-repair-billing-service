require "openssl"

module Payments
  module Services
    # Validates the `x-signature` header sent by Mercado Pago webhooks:
    # "ts=<timestamp>,v1=<hmac>", where the HMAC-SHA256 is computed over
    # "id:<data.id lowercased>;request-id:<x-request-id>;ts:<ts>;".
    class WebhookSignature
      def self.valid?(secret:, signature:, request_id:, data_id:)
        new(secret: secret, signature: signature, request_id: request_id, data_id: data_id).valid?
      end

      def self.sign(secret:, request_id:, data_id:, ts:)
        manifest = "id:#{data_id.to_s.downcase};request-id:#{request_id};ts:#{ts};"
        OpenSSL::HMAC.hexdigest("SHA256", secret, manifest)
      end

      def initialize(secret:, signature:, request_id:, data_id:)
        @secret     = secret
        @signature  = signature.to_s
        @request_id = request_id
        @data_id    = data_id
      end

      def valid?
        parts    = parse
        ts       = parts["ts"]
        received = parts["v1"]
        return false if @secret.blank? || ts.blank? || received.blank?

        expected = self.class.sign(secret: @secret, request_id: @request_id, data_id: @data_id, ts: ts)
        ActiveSupport::SecurityUtils.secure_compare(expected, received)
      end

      private

      def parse
        @signature.split(",").each_with_object({}) do |pair, acc|
          key, value = pair.split("=", 2)
          acc[key.to_s.strip] = value.to_s.strip if key
        end
      end
    end
  end
end
