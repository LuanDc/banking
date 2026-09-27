defmodule E2E.Load.Stats do
  @moduledoc """
  Latency summaries for the load report, in milliseconds.
  """

  @type summary :: %{
          count: non_neg_integer(),
          min: number() | nil,
          p50: number() | nil,
          p95: number() | nil,
          p99: number() | nil,
          max: number() | nil
        }

  @doc "Count, min, max and nearest-rank percentiles of the samples; `nil` when there are none."
  @spec summary([number()]) :: summary
  def summary(samples) do
    sorted = Enum.sort(samples)
    count = length(sorted)

    %{
      count: count,
      min: List.first(sorted),
      p50: percentile(sorted, count, 50),
      p95: percentile(sorted, count, 95),
      p99: percentile(sorted, count, 99),
      max: List.last(sorted)
    }
  end

  defp percentile(sorted, count, p), do: Enum.at(sorted, ceil(p * count / 100) - 1)
end
