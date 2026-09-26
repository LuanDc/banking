defmodule Ledger.Messaging.InboxIntegrationTest do
  # Smoke test: a message goes all the way to the aggregate through Ledger.App. How each
  # message becomes a command is covered by the pure to_command/1 tests.
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Ledger.Messaging.Inbox

  test "dispatches the command composed from each message" do
    # The event store has no sandbox: a fresh id keeps this stream apart from other runs.
    payload = %{"account_id" => Ecto.UUID.generate()}

    assert :ok = Inbox.handle(%{"type" => "OpenLedgerAccount", "payload" => payload})
    assert :ok = Inbox.handle(%{"type" => "CloseLedgerAccount", "payload" => payload})
  end
end
