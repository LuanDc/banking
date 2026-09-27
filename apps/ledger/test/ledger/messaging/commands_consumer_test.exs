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

  @tag :integration
  test "the command it dispatches joins the message's conversation, caused by the message" do
    account_id = Ecto.UUID.generate()
    body = Jason.encode!(%{account_id: account_id})
    [correlation_id, message_id] = [Ecto.UUID.generate(), Ecto.UUID.generate()]

    ref =
      Broadway.test_message(CommandsConsumer, body,
        metadata: %{
          type: "OpenLedgerAccount",
          correlation_id: correlation_id,
          message_id: message_id
        }
      )

    assert_receive {:ack, ^ref, [_successful], []}, 5_000

    {:ok, [opened]} =
      Ledger.EventStore.read_stream_backward("ledger-account-" <> account_id, -1, 1)

    assert {opened.correlation_id, opened.causation_id} == {correlation_id, message_id}
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
