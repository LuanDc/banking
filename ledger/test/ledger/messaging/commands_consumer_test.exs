defmodule Ledger.Messaging.CommandsConsumerTest do
  # In test the pipeline runs on Broadway.DummyProducer: messages come from test_message/3,
  # and the acknowledgement comes back to the test process. How each message becomes a
  # command is covered by the pure Inbox tests.
  use ExUnit.Case, async: false

  alias Ledger.Messaging.CommandsConsumer

  @tag :integration
  test "acknowledges a command once the aggregate took it" do
    # The event store has no sandbox: a fresh id keeps this stream apart from other runs.
    body = Jason.encode!(%{account_id: Ecto.UUID.generate()})

    ref = Broadway.test_message(CommandsConsumer, body, metadata: %{type: "OpenLedgerAccount"})

    assert_receive {:ack, ^ref, [_successful], []}, 5_000
  end

  test "fails a message whose command the Ledger does not accept" do
    ref =
      Broadway.test_message(CommandsConsumer, ~s({"account_id": "acc-1"}),
        metadata: %{type: "DeleteLedgerAccount"}
      )

    assert_receive {:ack, ^ref, [], [failed]}
    assert failed.status == {:failed, :unknown_command}
  end

  test "fails a message whose body is not JSON" do
    ref =
      Broadway.test_message(CommandsConsumer, "not json", metadata: %{type: "OpenLedgerAccount"})

    assert_receive {:ack, ^ref, [], [failed]}
    assert failed.status == {:failed, :invalid_json}
  end
end
