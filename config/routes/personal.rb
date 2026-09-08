# frozen_string_literal: true

get "/quick", to: "quick_pushes#new", as: :new_quick_push
post "/quick", to: "quick_pushes#create", as: :quick_pushes

get "/s/:id/passphrase", to: "quick_pushes#passphrase", as: :quick_passphrase
post "/s/:id/access", to: "quick_pushes#access", as: :quick_access
get "/s/:id", to: "quick_pushes#show", as: :quick_push
