require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.to_s + "/swagger"

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Billing Service API",
        version: "v1",
        description: "Orçamentos e pagamentos da oficina (Billing Service)"
      },
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        },
        schemas: {}
      },
      servers: [
        { url: "/", description: "Current host" }
      ]
    }
  }

  config.openapi_format = :yaml
end
