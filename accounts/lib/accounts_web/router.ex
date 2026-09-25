defmodule AccountsWeb.Router do
  use AccountsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AccountsWeb do
    pipe_through :api

    post "/accounts", AccountController, :create
    get "/accounts/:account_id", AccountController, :show

    post "/accounts/:account_id/activate", LifecycleController, :activate
    post "/accounts/:account_id/block", LifecycleController, :block
    post "/accounts/:account_id/unblock", LifecycleController, :unblock
    post "/accounts/:account_id/freeze", LifecycleController, :freeze
    post "/accounts/:account_id/unfreeze", LifecycleController, :unfreeze
    post "/accounts/:account_id/close", LifecycleController, :close
  end
end
