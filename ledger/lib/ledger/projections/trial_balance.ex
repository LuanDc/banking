defmodule Ledger.Projections.TrialBalance do
  @moduledoc """
  Read-only view totalling every account's debits and credits, the TrialBalanceView (README,
  section 7). The two totals are equal whenever the ledger is sound (section 4.1).
  """

  use Ecto.Schema

  @primary_key false

  schema "trial_balance" do
    field :debit_total, :integer
    field :credit_total, :integer
  end
end
