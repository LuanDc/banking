defmodule Accounts.Messaging.LedgerEventsConsumerTest do
  # In test the pipeline runs on Broadway.DummyProducer: messages come from test_message/3,
  # and the acknowledgement comes back to the test process. How each event becomes commands is
  # covered by the pure LedgerEventsInbox tests.
  use ExUnit.Case, async: false

  alias Accounts.App
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Messaging.LedgerEventsConsumer

  @tag :integration
  test "acknowledges an event once its commands were dispatched" do
    # The event store has no sandbox: a fresh id keeps this stream apart from other runs. A
    # confirmation for an account with no such reservation is accepted and does nothing (D4).
    body =
      Jason.encode!(%{
        batch_id: "corr-1",
        transfer_id: "corr-1",
        entries: [%{account_id: Ecto.UUID.generate(), type: "debit", amount: 400}]
      })

    ref =
      Broadway.test_message(LedgerEventsConsumer, body, metadata: %{type: "LedgerBatchBooked"})

    assert_receive {:ack, ^ref, [_successful], []}, 5_000
  end

  @tag :integration
  test "the commands it dispatches join the message's conversation, caused by the message" do
    account_id = Ecto.UUID.generate()
    :ok = App.dispatch(%OpenCustomerAccount{account_id: account_id, customer_id: "cus-1"})
    :ok = App.dispatch(%ActivateCustomerAccount{account_id: account_id})

    body =
      Jason.encode!(%{
        batch_id: Ecto.UUID.generate(),
        transfer_id: Ecto.UUID.generate(),
        entries: [%{account_id: account_id, type: "credit", amount: 400}]
      })

    [correlation_id, message_id] = [Ecto.UUID.generate(), Ecto.UUID.generate()]

    ref =
      Broadway.test_message(LedgerEventsConsumer, body,
        metadata: %{
          type: "LedgerBatchBooked",
          correlation_id: correlation_id,
          message_id: message_id
        }
      )

    assert_receive {:ack, ^ref, [_successful], []}, 5_000

    {:ok, [posted]} =
      Accounts.EventStore.read_stream_backward("customer-account-" <> account_id, -1, 1)

    assert {posted.correlation_id, posted.causation_id} == {correlation_id, message_id}
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
