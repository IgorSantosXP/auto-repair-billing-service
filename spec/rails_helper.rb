require "spec_helper"

ENV["RAILS_ENV"] = "test"
ENV["JWT_SECRET"] ||= "test_secret"
ENV["DD_TRACE_ENABLED"] = "false"

require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "webmock/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  config.before do
    WebMock.disable_net_connect!
    ActionMailer::Base.deliveries.clear
    Messaging.bus = Support::FakeBus.new
    %w[MERCADO_PAGO_MODE MERCADO_PAGO_ACCESS_TOKEN MERCADO_PAGO_WEBHOOK_SECRET FAKE_MERCADO_PAGO_REFUND_FAILS].each { |key| ENV.delete(key) }
    ENV["BILLING_PUBLIC_URL"] = "http://billing.test"
  end
end
