defmodule Ledger.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        LedgerWeb.Telemetry,
        Ledger.Repo,
        {DNSCluster, query: Application.get_env(:ledger, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Ledger.PubSub},
        Ledger.App
      ] ++
        projection_children() ++
        [
          # Commands from other services, dispatched through Ledger.App (README, D3).
          Ledger.Messaging.CommandsConsumer,
          # Start to serve requests, typically the last entry
          LedgerWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ledger.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # The read models, each fed by its own subscription to the event store (README, D11). Tests
  # turn them off, so no projector consumes the shared test event store on its own.
  defp projection_children do
    if Application.get_env(:ledger, :start_projections, true) do
      [
        Ledger.Projectors.LedgerAccountsProjector,
        Ledger.Projectors.BalancesProjector,
        Ledger.Projectors.StatementProjector
      ]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LedgerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
