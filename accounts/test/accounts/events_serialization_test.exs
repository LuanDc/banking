defmodule Accounts.EventsSerializationTest do
  use ExUnit.Case, async: true

  alias Accounts.Events
  alias Commanded.Serialization.JsonSerializer

  # One sample of every event CustomerAccount emits. The event store keeps them as JSON,
  # and the aggregate is rebuilt from what comes back, so each one must round-trip unchanged.
  @events [
    %Events.CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"},
    %Events.CustomerAccountActivated{account_id: "acc-1"},
    %Events.CustomerAccountBlocked{account_id: "acc-1", reason: "suspected fraud"},
    %Events.CustomerAccountUnblocked{account_id: "acc-1"},
    %Events.CustomerAccountFrozen{account_id: "acc-1", reason: "court order"},
    %Events.CustomerAccountUnfrozen{account_id: "acc-1"},
    %Events.CustomerAccountClosed{account_id: "acc-1"},
    %Events.BalanceReserved{account_id: "acc-1", amount: 400, correlation_id: "corr-1"},
    %Events.BalanceReservationRejected{
      account_id: "acc-1",
      amount: 400,
      correlation_id: "corr-1",
      reason: :insufficient_balance
    },
    %Events.ReservationConfirmed{account_id: "acc-1", correlation_id: "corr-1", amount: 400},
    %Events.BalanceReleased{account_id: "acc-1", correlation_id: "corr-1", amount: 400},
    %Events.CreditAuthorized{account_id: "acc-1", amount: 400, correlation_id: "corr-1"},
    %Events.CreditRejected{
      account_id: "acc-1",
      amount: 400,
      correlation_id: "corr-1",
      reason: :credit_not_allowed
    },
    %Events.CreditPosted{account_id: "acc-1", amount: 400, correlation_id: "corr-1"},
    %Events.CreditCancelled{account_id: "acc-1", correlation_id: "corr-1", amount: 400}
  ]

  for event <- @events do
    @event event
    test "#{inspect(event.__struct__)} round-trips through the JSON serializer" do
      type = Atom.to_string(@event.__struct__)

      assert @event ==
               @event |> JsonSerializer.serialize() |> JsonSerializer.deserialize(type: type)
    end
  end
end
