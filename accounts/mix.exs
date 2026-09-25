defmodule Accounts.MixProject do
  use Mix.Project

  def project do
    [
      app: :accounts,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/project.plt"},
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Accounts.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # CQRS / Event sourcing
      {:commanded, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      {:eventstore, "~> 1.4"},
      {:commanded_ecto_projections, "~> 1.4"},

      # Messaging
      {:amqp, "~> 4.2"},

      # Static analysis & security
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.15.0", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},

      # Testing
      {:excoveralls, "~> 0.18.5", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:faker, "~> 0.19.0", only: [:dev, :test]},
      {:mox, "~> 1.3", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # The event store comes first: the seeds in ecto.setup start the app, and with it Commanded.
      setup: ["deps.get", "event_store.setup", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "event_store.setup": ["event_store.create", "event_store.init"],
      "event_store.reset": ["event_store.drop", "event_store.setup"],
      test: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "event_store.create --quiet",
        "event_store.init --quiet",
        "test"
      ],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "sobelow --config",
        "deps.audit",
        "dialyzer"
      ]
    ]
  end
end
