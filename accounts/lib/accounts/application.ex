defmodule Accounts.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        AccountsWeb.Telemetry,
        Accounts.Repo,
        {DNSCluster, query: Application.get_env(:accounts, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Accounts.PubSub},
        Accounts.App
      ] ++
        projection_children() ++
        messaging_children() ++
        policy_children() ++
        [
          # Start to serve requests, typically the last entry
          AccountsWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Accounts.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # The read models, each fed by its own subscription to the event store (README, D11). Tests
  # turn them off, so no projector consumes the shared test event store on its own.
  defp projection_children do
    if Application.get_env(:accounts, :start_projections, true) do
      [
        Accounts.Handlers.Projectors.CustomerAccountsProjector,
        Accounts.Handlers.Projectors.ReservationsProjector,
        Accounts.Handlers.Projectors.CreditsProjector
      ]
    else
      []
    end
  end

  # The RabbitMQ connection, then the handler that publishes through it (README, D3). Tests
  # turn them off, so no handler consumes the event store on its own.
  defp messaging_children do
    if Application.get_env(:accounts, :start_messaging, true) do
      [Accounts.Messaging.RabbitMQPublisher, Accounts.Handlers.LedgerCommandsPublisher]
    else
      []
    end
  end

  # The transfer saga (README, section 5). Tests turn it off, so no policy dispatches from the
  # shared test event store on its own.
  defp policy_children do
    if Application.get_env(:accounts, :start_policies, true) do
      [Accounts.Handlers.LedgerRouter]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AccountsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
