defmodule Ledger.TransactionBatch do
  @moduledoc """
  Aggregate guarding the double-entry invariant: the debits of a batch equal its credits.
  """

  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected

  defstruct [:batch_id]

  def execute(%__MODULE__{}, %BookTransactionBatch{} = command) do
    if balanced?(command.entries) do
      %LedgerBatchBooked{
        batch_id: command.batch_id,
        correlation_id: command.correlation_id,
        entries: command.entries
      }
    else
      %LedgerBatchRejected{
        batch_id: command.batch_id,
        correlation_id: command.correlation_id,
        reason: :unbalanced
      }
    end
  end

  # README, section 4.1: sum(DEBIT) - sum(CREDIT) = 0.
  defp balanced?(entries), do: total(entries, :debit) == total(entries, :credit)

  defp total(entries, type) do
    entries
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end
end
