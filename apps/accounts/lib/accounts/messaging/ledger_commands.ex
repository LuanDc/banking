defmodule Accounts.Messaging.LedgerCommands do
  @moduledoc """
  Turns Account Management facts into the commands the Ledger accepts (README, D3 and D5).

  The Ledger knows no other context: it defines this command contract, and Accounts conforms
  to it. A message carries the command `type`, its `payload` and a `message_id` taken from the
  event that caused it, for tracing.
  """

  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Messaging.BatchId

  def for_event(%CustomerAccountOpened{} = event, metadata) do
    message("OpenLedgerAccount", %{account_id: event.account_id}, metadata)
  end

  def for_event(%CustomerAccountClosed{} = event, metadata) do
    message("CloseLedgerAccount", %{account_id: event.account_id}, metadata)
  end

  # README, D17: the batch has an id of its own, derived from the transfer's, so a redelivered
  # command hits a batch already decided and books nothing twice (D4).
  def for_event(%CreditAuthorized{} = event, metadata) do
    message(
      "BookTransactionBatch",
      %{
        batch_id: BatchId.settlement(event.transfer_id),
        transfer_id: event.transfer_id,
        entries: [
          %{account_id: event.from_account_id, type: "debit", amount: event.amount},
          %{account_id: event.account_id, type: "credit", amount: event.amount}
        ]
      },
      metadata
    )
  end

  defp message(type, payload, metadata) do
    %{message_id: metadata.event_id, type: type, payload: payload}
  end
end
