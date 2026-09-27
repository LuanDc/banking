defmodule Accounts.Messaging.LedgerEventsInbox do
  @moduledoc """
  Entry point for the Ledger's events (README, D3), the answers to the batches Accounts sent.

  The Ledger defines the event contract. A message is a decoded JSON map with the event `type`
  and its `payload`; the inbox turns it into the commands of the saga's last step, one per
  customer account the batch touched, and dispatches them:

    * `LedgerBatchBooked` confirms each debited reservation and posts each credit.
    * `LedgerBatchRejected` releases each debited reservation and cancels each pending credit.

  The bank's own accounts are left out: no `CustomerAccount` stands behind them. Every command is
  idempotent by `transfer_id` (D4), so a redelivered event changes nothing.
  """

  alias Accounts.App
  alias Accounts.BankAccounts
  alias Accounts.Commands.CancelCredit
  alias Accounts.Commands.ConfirmReservation
  alias Accounts.Commands.PostCredit
  alias Accounts.Commands.ReleaseBalance

  @doc "Dispatches the message's commands, with the lineage it came with (README, D17)."
  def handle(message, lineage \\ []) do
    with {:ok, commands} <- to_commands(message) do
      Enum.reduce_while(commands, :ok, &dispatch(&1, &2, lineage))
    end
  end

  def to_commands(%{"type" => "LedgerBatchBooked", "payload" => payload}) do
    {:ok, commands(payload, &booked/2)}
  end

  def to_commands(%{"type" => "LedgerBatchRejected", "payload" => payload}) do
    {:ok, commands(payload, &rejected/2)}
  end

  def to_commands(_message), do: {:error, :unknown_event}

  defp dispatch(command, :ok, lineage) do
    case App.dispatch(command, lineage) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end

  defp commands(payload, command_for) do
    payload["entries"]
    |> Enum.reject(&BankAccounts.bank_account?(&1["account_id"]))
    |> Enum.map(&command_for.(&1, payload["transfer_id"]))
  end

  defp booked(%{"type" => "debit"} = entry, transfer_id) do
    %ConfirmReservation{account_id: entry["account_id"], transfer_id: transfer_id}
  end

  defp booked(%{"type" => "credit"} = entry, transfer_id) do
    %PostCredit{
      account_id: entry["account_id"],
      amount: entry["amount"],
      transfer_id: transfer_id
    }
  end

  defp rejected(%{"type" => "debit"} = entry, transfer_id) do
    %ReleaseBalance{account_id: entry["account_id"], transfer_id: transfer_id}
  end

  defp rejected(%{"type" => "credit"} = entry, transfer_id) do
    %CancelCredit{account_id: entry["account_id"], transfer_id: transfer_id}
  end
end
