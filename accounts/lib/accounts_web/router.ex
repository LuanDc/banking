defmodule AccountsWeb.Router do
  use AccountsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AccountsWeb do
    pipe_through :api

    get "/accounts/:account_id", AccountController, :show
  end
end
