module Telemetry
  NAMESPACE = "auto_repair".freeze

  module_function

  def enabled?
    ENV["DD_AGENT_HOST"].present?
  end

  def client
    return nil unless enabled?

    @client ||= Datadog::Statsd.new(
      ENV.fetch("DD_AGENT_HOST"),
      ENV.fetch("DD_DOGSTATSD_PORT", "8125").to_i,
      namespace: NAMESPACE,
      tags: base_tags
    )
  end

  def base_tags
    [
      "env:#{ENV.fetch('DD_ENV', Rails.env)}",
      "service:#{ENV.fetch('DD_SERVICE', 'billing-service')}"
    ]
  end

  def budget_status(status)
    increment("billing.budget", tags: [ "status:#{status}" ])
  end

  def payment_status(status)
    increment("billing.payment", tags: [ "status:#{status}" ])
  end

  def integration_error(integration:, reason:)
    increment("integration.error", tags: [ "integration:#{integration}", "reason:#{reason}" ])
  end

  def increment(metric, tags: [])
    client&.increment(metric, tags: base_tags + tags)
  rescue StandardError => e
    Rails.logger.warn("[Telemetry] Failed to emit #{metric}: #{e.message}")
  end

  def distribution(metric, value, tags: [])
    client&.distribution(metric, value, tags: base_tags + tags)
  rescue StandardError => e
    Rails.logger.warn("[Telemetry] Failed to emit #{metric}: #{e.message}")
  end
end
