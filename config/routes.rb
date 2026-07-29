Rails.application.routes.draw do
  # ログインとログアウト。
  resource :session, only: %i[new create destroy]

  # /up はアプリケーションが起動できたかだけを返す。
  # /health は依存先への到達可否まで含めて返す。用途に応じて使い分ける。
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show", as: :health

  # 表示言語の切り替え。状態を変えるため GET では受け付けない。
  patch "locale" => "locales#update", as: :locale

  # お知らせ。
  resources :announcements

  # 予定。
  resources :events

  # 外部からの接続に使う token の管理。
  resources :api_tokens, only: %i[index create destroy]

  # 外部からの接続。
  namespace :api do
    namespace :v1 do
      resources :announcements, only: %i[index]
      resources :events, only: %i[index]
      resources :departments, only: %i[index]
      resources :users, only: %i[index]
    end
  end

  # 自分の設定。
  resource :settings, only: %i[show update]

  # 通知。
  resources :notifications, only: %i[index show]

  # 文書。
  resources :documents do
    # 添付の取得も文書の参照範囲に従わせるため、独自の経路を通す。
    resources :attachments, only: %i[show], controller: "document_attachments"
  end
  resources :document_categories, only: %i[index new create edit update]

  # 申請。
  resources :request_types, only: %i[index new create edit update]
  resources :requests, except: %i[destroy] do
    resource :submission, only: %i[create destroy], controller: "request_submissions"
    resource :decision, only: %i[create], controller: "request_decisions"
  end

  # 設備・備品の予約。
  resources :reservations, only: %i[index new create destroy]

  # 設備・備品。使えなくなったものは削除せず、予約を受け付けない状態にする。
  resources :resources, except: %i[destroy]

  # 利用者の管理。削除ではなく無効化で利用を止める。
  resources :users, only: %i[index new create edit update] do
    resource :activation, only: %i[create destroy], controller: "user_activations"
  end

  # 組織と部門。
  resources :departments do
    resources :memberships, only: %i[create destroy]
  end

  root "home#show"
end
