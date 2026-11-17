module Payments
  module Gateways
    module Factory
      module_function

      def build(mode: Settings.mode)
        case mode
        when "fake" then FakeMercadoPago.new
        when "live" then MercadoPago.new
        else raise ArgumentError, "Unknown MERCADO_PAGO_MODE '#{mode}'"
        end
      end
    end
  end
end
