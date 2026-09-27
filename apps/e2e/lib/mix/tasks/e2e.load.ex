defmodule Mix.Tasks.E2e.Load do
  @shortdoc "Runs a load test against the running services and checks both books"

  @moduledoc """
  Runs `E2E.Load` against the running services, prints the report and fails when the books
  don't add up. `scripts/load.sh`, from the repo root, starts the stack with the load limits
  first.

      mix e2e.load --rate 50 --duration 60 --accounts 50 --mix transfer=80,deposit=15,read=5

  ## Options

    * `--rate` - operations started per second (default 20)
    * `--duration` - seconds of load (default 30)
    * `--accounts` - funded accounts in the pool (default 20)
    * `--balance` - cents each pool account starts with (default 1_000_000)
    * `--mix` - operation weights (default `transfer=80,deposit=15,read=5`)
    * `--poll` - ms between two reads while waiting for an outcome (default 100)
    * `--settle-timeout` - seconds an operation waits for its outcome (default 30)
    * `--drain-timeout` - seconds the check waits for late outcomes and balances (default 120)
    * `--max-in-flight` - operations running at once before starts are dropped (default 2000)
    * `--pool-size` - HTTP connections per service (default 200)
    * `--out` - also write the report as JSON to this path
  """

  use Mix.Task

  alias E2E.Load
  alias E2E.Load.Report
  alias E2E.Load.Workload

  @switches [
    rate: :integer,
    duration: :integer,
    accounts: :integer,
    balance: :integer,
    mix: :string,
    poll: :integer,
    settle_timeout: :integer,
    drain_timeout: :integer,
    max_in_flight: :integer,
    pool_size: :integer,
    out: :string
  ]

  @impl Mix.Task
  def run(argv) do
    {opts, settings} =
      case parse_args(argv) do
        {:ok, opts, settings} -> {opts, settings}
        {:error, message} -> Mix.raise(message)
      end

    Mix.Task.run("app.start")
    E2E.Preflight.check!()
    use_pool(settings.pool_size)

    report = Load.run(opts)
    Mix.shell().info(Report.format(report))
    write(report, settings.out)

    unless report.consistency.ok, do: Mix.raise("The books do not add up after the load test.")
  end

  @doc false
  @spec parse_args([String.t()]) :: {:ok, keyword(), map()} | {:error, String.t()}
  def parse_args(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {parsed, [], []} -> build(parsed)
      {_parsed, _args, [{switch, _value} | _]} -> {:error, "unknown option: #{switch}"}
      {_parsed, [arg | _], []} -> {:error, "unexpected argument: #{arg}"}
    end
  end

  defp build(parsed) do
    {settings, opts} = Keyword.split(parsed, [:out, :pool_size])
    settings = Map.merge(%{out: nil, pool_size: 200}, Map.new(settings))

    case Keyword.pop(opts, :mix) do
      {nil, opts} ->
        {:ok, opts, settings}

      {mix, opts} ->
        with {:ok, weights} <- Workload.parse_weights(mix),
             do: {:ok, opts ++ [weights: weights], settings}
    end
  end

  # Req's default pool is sized for tests, not for hundreds of requests in flight.
  defp use_pool(size) do
    {:ok, _supervisor} =
      Supervisor.start_link([{Finch, name: E2E.Load.Finch, pools: %{default: [size: size]}}],
        strategy: :one_for_one
      )

    Application.put_env(:e2e, :req_options, finch: [name: E2E.Load.Finch])
  end

  defp write(_report, nil), do: :ok

  defp write(report, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode_to_iodata!(report, pretty: true))
    Mix.shell().info("\n📝 Report written to #{path}")
  end
end
