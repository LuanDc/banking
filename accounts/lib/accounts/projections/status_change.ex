defmodule Accounts.Projections.StatusChange do
  @moduledoc """
  One step in the FSM history of a customer account (README, section 7).
  """

  use Ecto.Schema

  schema "customer_account_status_changes" do
    field :account_id, :string
    field :event, :string
    field :status, Ecto.Enum, values: [:pending_kyc, :active, :blocked, :frozen, :closed]
    field :reason, :string
    field :occurred_at, :utc_datetime_usec
  end
end
