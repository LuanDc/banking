defmodule E2E.Load.StatsTest do
  use ExUnit.Case, async: true

  alias E2E.Load.Stats

  test "summarizes latencies with nearest-rank percentiles" do
    samples = Enum.shuffle(1..100)

    assert Stats.summary(samples) == %{count: 100, min: 1, p50: 50, p95: 95, p99: 99, max: 100}
  end

  test "an empty sample has a count and no latencies" do
    assert Stats.summary([]) == %{count: 0, min: nil, p50: nil, p95: nil, p99: nil, max: nil}
  end
end
