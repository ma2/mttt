Rails.application.routes.draw do
  get "network_games/join"
  post "network_games/create_match"
  get "network_games/waiting"
  get "network_games/:id/check_match", to: "network_games#check_match", as: "check_match_network_game"
  post "games/:id/abandon", to: "games#abandon", as: "abandon_game"
  get "games/:id/check_abandoned", to: "games#check_abandoned", as: "check_abandoned_game"
  get "games/:id/check_opponent_move", to: "games#check_opponent_move", as: "check_opponent_move_game"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "games#new"
  get "howto", to: "games#howto"

  resources :games, only: [ :new, :create, :show ] do
    member do
      post :move, defaults: { format: :json }  # /games/:id/move
    end
  end

  # ネットワーク対戦用に API を追加する場合はここに追記
end
