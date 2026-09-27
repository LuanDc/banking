defmodule E2E.MixProject do
  use Mix.Project

  def project do
    [
      app: :e2e,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_local_path: "_build/plts",
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  # The suite drives the running services from outside, so nothing is started here.
  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      # Talking to the services: HTTP for the APIs, AMQP to replay messages (docs, D15).
      {:req, "~> 0.5"},
      {:amqp, "~> 4.2"},
      {:jason, "~> 1.4"},

      # Static analysis & security
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "deps.audit",
        "dialyzer"
      ]
    ]
  end
end
