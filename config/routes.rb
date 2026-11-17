Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  post "webhooks/mercadopago", to: "webhooks/mercado_pago#create"

  namespace :api do
    namespace :v1 do
      resources :budgets, param: :service_order_uuid, only: [ :index, :show ] do
        member do
          match :approve, via: [ :get, :post ]
          match :reject,  via: [ :get, :post ]
        end
      end

      post "payments/:service_order_uuid/simulate", to: "payments#simulate"
    end
  end
end
