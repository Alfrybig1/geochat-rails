GeochatRails::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  root :to => "home#index"

  resource :session, :only => [:new, :create, :destroy] do
    post 'register', :on => :member
  end

  resources :channels, :only => [:index, :destroy] do
    new do
      get 'email' => 'channels#new_email'
      post 'email' => 'channels#create_email'
    end
    member do
      get 'activate_email'
      get 'turn_on'
      get 'turn_off'
    end
  end

  match "/nuntium/receive_at" => "nuntium#receive_at"

  scope "/api" do
    scope "/users" do
      match "/create/:login" => "api#create_user"
      match "/:login" => "api#user"
      match "/:login/verify" => "api#verify_user_credentials"
      match "/:login/groups" => "api#user_groups"
    end

    scope "/groups" do
      match "/:alias" => "api#group"
      match "/:alias/members" => "api#group_members"
      match "/:alias/messages" => "api#group_messages"
    end
  end

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
