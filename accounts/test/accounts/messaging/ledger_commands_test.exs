defmodule Accounts.Messaging.LedgerCommandsTest do
  use ExUnit.Case, async: true

  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Messaging.LedgerCommands

  @metadata %{event_id: "evt-1"}

  test "opens the ledger account of a newly opened customer account" do
    event = %CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"}

    assert LedgerCommands.for_event(event, @metadata) == %{
             message_id: "evt-1",
             type: "OpenLedgerAccount",
             payload: %{account_id: "acc-1"}
           }
  end

  test "closes the ledger account of a closed customer account" do
    event = %CustomerAccountClosed{account_id: "acc-1"}

    assert LedgerCommands.for_event(event, @metadata) == %{
             message_id: "evt-1",
             type: "CloseLedgerAccount",
             payload: %{account_id: "acc-1"}
           }
  end
end
