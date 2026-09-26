defmodule Accounts.Messaging.LedgerEventsConsumerTest do
  # In test the pipeline runs on Broadway.DummyProducer: messages come from test_message/3,
  # and the acknowledgement comes back to the test process. How each event becomes commands is
  # covered by the pure LedgerEventsInbox tests.
  use ExUnit.Case, async: false

  alias Accounts.Messaging.LedgerEventsConsumer

  @tag :integration
  test "acknowledges an event once its commands were dispatched" do
    # The event store has no sandbox: a fresh id keeps this stream apart from other runs. A
    # confirmation for an account with no such reservation is accepted and does nothing (D4).
    body =
      Jason.encode!(%{
        batch_id: "corr-1",
        correlation_id: "corr-1",
        entries: [%{account_id: Ecto.UUID.generate(), type: "debit", amount: 400}]
      })

    ref =
      Broadway.test_message(LedgerEventsConsumer, body, metadata: %{type: "LedgerBatchBooked"})

    assert_receive {:ack, ^ref, [_successful], []}, 5_000
  end

  test "fails an event it does not know" do
    ref =
      Broadway.test_message(LedgerEventsConsumer, "{}", metadata: %{type: "LedgerBatchReversed"})

    assert_receive {:ack, ^ref, [], [failed]}
    assert failed.status == {:failed, :unknown_event}
  end

  test "fails a message whose body is not JSON" do
    ref =
      Broadway.test_message(LedgerEventsConsumer, "not json",
        metadata: %{type: "LedgerBatchBooked"}
      )

    assert_receive {:ack, ^ref, [], [failed]}
    assert failed.status == {:failed, :invalid_json}
  end
end
