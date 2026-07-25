Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Mounted at the literal paths from the assignment spec (kebab-case,
  # unversioned) even though the controller code is namespaced under
  # Api::V1 — `scope module:` decouples the two, so adding a real /api/v1
  # URL prefix (or a v2) later is a routes-only change, not a rewrite.
  scope module: "api/v1" do
    resources :bulk_actions, path: "bulk-actions", only: %i[index create show] do
      member do
        get :stats
        get :logs
        patch :cancel
      end
    end
  end
end
