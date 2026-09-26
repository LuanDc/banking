defmodule Accounts.Projections.CustomerAccount do
  @moduledoc """
  Read model of each customer account: its FSM status and available balance, the
  AccountStatusView (README, section 7).
  """

  use Ecto.Schema

  @primary_key {:account_id, :string, autogenerate: false}

  schema "customer_accounts" do
    field :customer_id, :string
    field :status, Ecto.Enum, values: [:pending_kyc, :active, :blocked, :frozen, :closed]
    field :status_reason, :string
    field :available_balance, :integer, default: 0
    field :opened_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :updated_at, :utc_datetime_usec
  end
end
