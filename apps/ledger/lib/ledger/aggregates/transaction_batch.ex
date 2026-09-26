defmodule Ledger.Aggregates.TransactionBatch do
  @moduledoc """
  Aggregate guarding the double-entry invariant: the debits of a batch equal its credits.
  """

  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected

  defstruct [:batch_id, :status]

  # README, D4: a redelivered command for a decided batch books nothing.
  def execute(%__MODULE__{status: status}, %BookTransactionBatch{})
      when status in [:booked, :rejected],
      do: []

  def execute(%__MODULE__{}, %BookTransactionBatch{} = command) do
    case validate(command) do
      :ok ->
        %LedgerBatchBooked{
          batch_id: command.batch_id,
          correlation_id: command.correlation_id,
          entries: command.entries
        }

      {:error, reason} ->
        %LedgerBatchRejected{
          batch_id: command.batch_id,
          correlation_id: command.correlation_id,
          reason: reason,
          entries: command.entries
        }
    end
  end

  def apply(%__MODULE__{} = batch, %LedgerBatchBooked{} = event) do
    %__MODULE__{batch | batch_id: event.batch_id, status: :booked}
  end

  def apply(%__MODULE__{} = batch, %LedgerBatchRejected{} = event) do
    %__MODULE__{batch | batch_id: event.batch_id, status: :rejected}
  end

  defp validate(%BookTransactionBatch{entries: []}), do: {:error, :empty}

  defp validate(%BookTransactionBatch{entries: entries} = command) do
    cond do
      not Enum.all?(entries, &(&1.type in [:debit, :credit])) -> {:error, :invalid_entry_type}
      not Enum.all?(entries, &valid_amount?/1) -> {:error, :invalid_amount}
      # README, D5: no entry into an account that is not open.
      command.accounts_not_open != [] -> {:error, :account_not_open}
      not balanced?(entries) -> {:error, :unbalanced}
      true -> :ok
    end
  end

  # README, D1: money is an integer number of cents.
  defp valid_amount?(%{amount: amount}), do: is_integer(amount) and amount > 0

  # README, section 4.1: sum(DEBIT) - sum(CREDIT) = 0.
  defp balanced?(entries), do: total(entries, :debit) == total(entries, :credit)

  defp total(entries, type) do
    entries
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end
end
