Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # /up はアプリケーションが起動できたかだけを返す。
  # /health は依存先への到達可否まで含めて返す。用途に応じて使い分ける。
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show", as: :health

  # 表示言語の切り替え。状態を変えるため GET では受け付けない。
  patch "locale" => "locales#update", as: :locale

  root "home#show"
end
