defmodule E2E.Load.Books do
  @moduledoc """
  The balance each account of the load test must end with, from the outcomes of what was sent.

  Only a completed transfer or a posted deposit moves money. A failed transfer was compensated,
  so it leaves both accounts as they were (docs, section 5).
  """

  @spec expected_balances(%{String.t() => integer()}, [map()]) :: %{String.t() => integer()}
  def expected_balances(initial, results), do: Enum.reduce(results, initial, &apply_result/2)

  defp apply_result(%{op: :transfer, outcome: "completed"} = result, balances) do
    balances
    |> Map.update!(result.from, &(&1 - result.amount))
    |> Map.update!(result.to, &(&1 + result.amount))
  end

  defp apply_result(%{op: :deposit, outcome: "posted"} = result, balances) do
    Map.update!(balances, result.to, &(&1 + result.amount))
  end

  defp apply_result(_moves_nothing, balances), do: balances
end
