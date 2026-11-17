module Payments
  # Reads the gateway configuration lazily so tests can change ENV per example.
  module Settings
    module_function

    def mode
      ENV.fetch("MERCADO_PAGO_MODE", "fake")
    end

    def fake?
      mode == "fake"
    end

    def public_url
      ENV.fetch("BILLING_PUBLIC_URL", "http://localhost:3001").chomp("/")
    end

    def access_token
      ENV.fetch("MERCADO_PAGO_ACCESS_TOKEN", nil)
    end

    def webhook_secret
      ENV.fetch("MERCADO_PAGO_WEBHOOK_SECRET", nil).presence
    end
  end
end
