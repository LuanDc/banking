defmodule E2E.Load.Report do
  @moduledoc """
  The load report as text for the terminal. `mix e2e.load` also writes it as JSON.
  """

  @operations [:transfer, :deposit, :read]

  @spec format(map()) :: String.t()
  def format(report) do
    [
      header(report),
      "",
      table(report.operations),
      errors(report.operations),
      "",
      backlog(report.backlog),
      "",
      consistency(report.consistency, report.config.accounts)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp header(%{config: config} = report) do
    mix =
      config.weights
      |> Enum.sort_by(fn {_operation, weight} -> -weight end)
      |> Enum.map_join(" ", fn {operation, weight} -> "#{operation}=#{weight}" end)

    """
    📈 Load: #{config.rate}/s for #{config.duration}s · #{config.accounts} accounts · mix #{mix}
       sent #{report.sent} · dropped #{report.dropped} · took #{report.elapsed_ms / 1_000}s · \
    generator lag p99 #{report.generator_lag.p99} ms\
    """
  end

  defp table(operations) do
    rows =
      for operation <- @operations,
          stats = operations[operation],
          count = Enum.sum(Map.values(stats.outcomes)),
          count > 0 do
        [
          to_string(operation),
          to_string(count),
          outcomes(stats.outcomes),
          latency(stats.accept),
          latency(stats.settle),
          to_string(stats.settled_per_second)
        ]
      end

    header = ["operation", "count", "outcomes", "accept ms", "settle ms", "settled/s"]
    subheader = ["", "", "", "p50 / p99 / max", "p50 / p99 / max", ""]

    [header, subheader | rows]
    |> Enum.map_join("\n", &row/1)
  end

  defp row(cells) do
    cells
    |> Enum.zip([11, 7, 36, 22, 22, 0])
    |> Enum.map_join(fn {cell, width} -> String.pad_trailing(cell, width) end)
    |> String.trim_trailing()
  end

  defp outcomes(outcomes) do
    outcomes
    |> Enum.sort_by(fn {_outcome, count} -> -count end)
    |> Enum.map_join(" · ", fn {outcome, count} -> "#{outcome} #{count}" end)
  end

  defp errors(operations) do
    lines =
      for operation <- @operations,
          %{errors: errors, recovered: recovered} = operations[operation],
          errors != %{} do
        "   #{operation}: " <> tally(errors) <> recovered(recovered)
      end

    if lines == [], do: [], else: ["", "⚠️ Errors, by reason:" | lines]
  end

  defp recovered(0), do: ""
  defp recovered(count), do: " (#{count} settled by a retry with the same key)"

  defp tally(counts) do
    counts
    |> Enum.sort_by(fn {_reason, count} -> -count end)
    |> Enum.map_join(" · ", fn {reason, count} -> "#{reason} ×#{count}" end)
  end

  defp latency(%{count: 0}), do: "-"
  defp latency(summary), do: "#{summary.p50} / #{summary.p99} / #{summary.max}"

  defp backlog(backlog) do
    queues =
      backlog
      |> Enum.sort()
      |> Enum.map_join(" · ", fn {queue, messages} -> "#{queue}: #{messages}" end)

    "🐇 Max backlog: " <> queues
  end

  defp consistency(consistency, accounts) do
    details =
      "trial balance #{if consistency.balanced, do: "balanced", else: "NOT balanced"} · " <>
        "dead letters: #{consistency.dead_letters} · unresolved: #{consistency.unresolved}"

    if consistency.ok do
      "✅ Both books agree on all #{accounts} accounts · " <> details
    else
      mismatches =
        Enum.map(consistency.mismatches, fn mismatch ->
          "   #{mismatch.account_id}: expected #{mismatch.expected}, " <>
            "accounts #{mismatch.accounts}, ledger #{mismatch.ledger}"
        end)

      Enum.join(["❌ The books do not add up" | mismatches] ++ ["   " <> details], "\n")
    end
  end
end
