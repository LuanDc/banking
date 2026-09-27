defmodule Ledger.Handlers.ProjectorFailuresTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias Commanded.Event.FailureContext
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Handlers.ProjectorFailures
  alias Ledger.Handlers.Projectors.BalancesProjector
  alias Ledger.Handlers.Projectors.LedgerAccountsProjector
  alias Ledger.Handlers.Projectors.StatementProjector

  @event %LedgerBatchBooked{batch_id: "batch-1", transfer_id: "transfer-1"}
  @pool_error {:error, %DBConnection.ConnectionError{message: "connection not available"}}

  describe "an error of the infrastructure (README, D18)" do
    test "is retried after 100 ms the first time" do
      assert {:retry, 100, %FailureContext{}} =
               ProjectorFailures.error(@pool_error, @event, failure_context())
    end

    test "waits twice as long at each attempt, up to 30 s, and never gives up" do
      delays =
        Enum.map_reduce(1..12, failure_context(), fn _attempt, failure_context ->
          {:retry, delay, failure_context} =
            ProjectorFailures.error(@pool_error, @event, failure_context)

          {delay, failure_context}
        end)
        |> elem(0)

      assert delays == [
               100,
               200,
               400,
               800,
               1_600,
               3_200,
               6_400,
               12_800,
               25_600,
               30_000,
               30_000,
               30_000
             ]
    end
  end

  test "every projector waits out the infrastructure instead of stopping" do
    for projector <- [BalancesProjector, LedgerAccountsProjector, StatementProjector] do
      assert {:retry, 100, _failure_context} =
               projector.error(@pool_error, @event, failure_context()),
             inspect(projector)
    end
  end

  describe "infrastructure?/1" do
    test "holds for a Postgres error a retry can outlive" do
      for pg_code <- ["08006", "53300", "57014", "57P01", "40001", "40P01"] do
        assert ProjectorFailures.infrastructure?(postgrex_error(pg_code)), pg_code
      end
    end

    test "does not hold for an event that breaks a constraint" do
      refute ProjectorFailures.infrastructure?(postgrex_error("23505"))
      refute ProjectorFailures.infrastructure?(postgrex_error("23502"))
    end
  end

  describe "an error of the code or the data (README, D18)" do
    test "stops the projector at once: no retry can fix it" do
      bug = %FunctionClauseError{module: Entry, function: :new, arity: 1}

      assert {:stop, ^bug} = ProjectorFailures.error({:error, bug}, @event, failure_context())
    end
  end

  defp postgrex_error(pg_code), do: %Postgrex.Error{postgres: %{pg_code: pg_code}}

  defp failure_context(context \\ %{}) do
    %FailureContext{
      handler_name: "balances_projector",
      context: context,
      metadata: %{event_number: 42}
    }
  end
end
