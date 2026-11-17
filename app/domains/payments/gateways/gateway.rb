module Payments
  module Gateways
    # Port implemented by the Mercado Pago adapters (live and fake).
    #
    #   create_preference(budget)  -> { preference_id:, payment_url: }
    #   fetch_payment(id)          -> { id:, status:, transaction_amount:, external_reference: }
    #   refund(payment)            -> { id:, amount: }
    #
    # Every method raises Payments::Errors::GatewayError on failure.
    class Gateway
      def create_preference(_budget)
        raise NotImplementedError
      end

      def fetch_payment(_payment_id)
        raise NotImplementedError
      end

      def refund(_payment)
        raise NotImplementedError
      end

      def mode
        raise NotImplementedError
      end
    end
  end
end
