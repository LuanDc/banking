defmodule E2E.Load.WorkloadTest do
  use ExUnit.Case, async: true

  alias E2E.Load.Workload

  describe "plan/2" do
    test "deals the operations in shuffled cycles that each hold every weight exactly" do
      plan = Workload.plan([transfer: 2, deposit: 1], 7)

      assert length(plan) == 7

      for cycle <- Enum.chunk_every(plan, 3, 3, :discard) do
        assert Enum.frequencies(cycle) == %{transfer: 2, deposit: 1}
      end
    end
  end

  describe "arrivals/2" do
    test "spaces rate × duration starts evenly, in ms from the start" do
      assert Workload.arrivals(4, 2) == [0, 250, 500, 750, 1000, 1250, 1500, 1750]
    end
  end

  describe "parse_weights/1" do
    test "reads operation=weight pairs, in order" do
      assert Workload.parse_weights("transfer=80,deposit=15,read=5") ==
               {:ok, [transfer: 80, deposit: 15, read: 5]}
    end

    test "refuses an unknown operation or a weight that is not a positive integer" do
      assert {:error, "unknown operation: withdraw"} = Workload.parse_weights("withdraw=10")
      assert {:error, "invalid weight: transfer=0"} = Workload.parse_weights("transfer=0")
      assert {:error, "invalid weight: deposit=x"} = Workload.parse_weights("deposit=x")
    end
  end
end
