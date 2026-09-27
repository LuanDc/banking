defmodule Ledger.Factory do
  @moduledoc """
  ExMachina factories for the read models, so API tests can read rows without replaying events.

  Use `insert(:ledger_account)`, `build(:account_balance)` or `params_for(:statement_entry)`.
  """

  use ExMachina.Ecto, repo: Ledger.Repo

  alias Ledger.Projections.AccountBalance
  alias Ledger.Projections.LedgerAccount
  alias Ledger.Projections.StatementEntry

  def ledger_account_factory do
    %LedgerAccount{
      account_id: Ecto.UUID.generate(),
      status: :open,
      opened_at: DateTime.utc_now()
    }
  end

  def account_balance_factory do
    %AccountBalance{
      account_id: Ecto.UUID.generate(),
      debit_total: 0,
      credit_total: 1_000,
      updated_at: DateTime.utc_now()
    }
  end

  def statement_entry_factory do
    %StatementEntry{
      batch_id: sequence(:batch_id, &"batch-#{&1}"),
      transfer_id: sequence(:transfer_id, &"corr-#{&1}"),
      position: 0,
      account_id: Ecto.UUID.generate(),
      type: :credit,
      amount: 1_000,
      booked_at: DateTime.utc_now()
    }
  end
end
