defmodule Ledger.Messaging.Inbox do
  @moduledoc """
  Entry point for command messages from other services (README, D3).

  The Ledger defines this command contract and knows nothing of who sends it. A message is a
  decoded JSON map with a command `type` and its `payload`; the inbox composes the command and
  dispatches it to the aggregate. It holds no business rule: validation stays in the aggregates.
  """

  alias Ledger.App
  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Commands.CloseLedgerAccount
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.LedgerEntry

  def handle(message) do
    with {:ok, command} <- to_command(message) do
      App.dispatch(command, dispatch_opts(command))
    end
  end

  @doc """
  Opening and closing wait for the strongly consistent ledger accounts projection, so the D5
  check of the next batch on the queue already sees the account (README, D5).
  """
  def dispatch_opts(%OpenLedgerAccount{}), do: [consistency: :strong]
  def dispatch_opts(%CloseLedgerAccount{}), do: [consistency: :strong]
  def dispatch_opts(_command), do: []

  def to_command(%{"type" => "OpenLedgerAccount", "payload" => payload}) do
    {:ok, %OpenLedgerAccount{account_id: payload["account_id"]}}
  end

  def to_command(%{"type" => "CloseLedgerAccount", "payload" => payload}) do
    {:ok, %CloseLedgerAccount{account_id: payload["account_id"]}}
  end

  def to_command(%{"type" => "BookTransactionBatch", "payload" => payload}) do
    {:ok,
     %BookTransactionBatch{
       batch_id: payload["batch_id"],
       transfer_id: payload["transfer_id"],
       entries: Enum.map(payload["entries"], &to_entry/1)
     }}
  end

  def to_command(_message), do: {:error, :unknown_command}

  defp to_entry(entry) do
    %LedgerEntry{
      account_id: entry["account_id"],
      type: entry_type(entry["type"]),
      amount: entry["amount"]
    }
  end

  # Only the known types become atoms. Anything else passes through as it came, so no atom
  # is created from outside input, and TransactionBatch rejects it as :invalid_entry_type.
  defp entry_type("debit"), do: :debit
  defp entry_type("credit"), do: :credit
  defp entry_type(other), do: other
end
