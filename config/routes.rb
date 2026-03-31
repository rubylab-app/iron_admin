IronAdmin::Engine.routes.draw do
  root "dashboard#index"

  get "search", to: "search#index", as: :search
  get "audit", to: "audit#index", as: :audit
  get "autocomplete/:resource_name", to: "resources#autocomplete", as: :autocomplete
  get ":resource_name/export", to: "exports#show", as: :export

  get "tools/:tool_name", to: "tools#show", as: :tool
  get "tools/:tool_name/:action_name/form", to: "tools#action_form", as: :tool_action_form
  post "tools/:tool_name/:action_name", to: "tools#execute", as: :tool_action

  get ":resource_name/bulk_actions/:action_name/form", to: "resources#bulk_action_form", as: :resource_bulk_action_form
  get ":resource_name", to: "resources#index", as: :resources
  get ":resource_name/new", to: "resources#new", as: :new_resource
  get ":resource_name/:id", to: "resources#show", as: :resource
  get ":resource_name/:id/edit", to: "resources#edit", as: :edit_resource
  get ":resource_name/:id/actions/:action_name/form", to: "resources#action_form", as: :resource_action_form
  post ":resource_name", to: "resources#create"
  patch ":resource_name/:id", to: "resources#update"
  delete ":resource_name/:id", to: "resources#destroy"
  post ":resource_name/:id/actions/:action_name", to: "resources#execute_action", as: :resource_action
  post ":resource_name/bulk_actions/:action_name", to: "resources#execute_bulk_action", as: :resource_bulk_action
end
