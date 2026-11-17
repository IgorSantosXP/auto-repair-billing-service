# Maps each consumed message type to a callable that receives the envelope.
module Handlers
  REGISTRY = {
    "billing.generate_budget" => GenerateBudget,
    "billing.cancel_budget"   => CancelBudget,
    "billing.refund_payment"  => RefundPayment
  }.freeze
end
