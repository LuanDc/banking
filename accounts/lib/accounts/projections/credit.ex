defmodule Accounts.Projections.Credit do
  @moduledoc """
  Read model of every credit to a customer account and how it settled (README, D8).
  """

  use Ecto.Schema

  schema "credits" do
    field :account_id, :string
    field :correlation_id, :string
    field :amount, :integer
    field :status, Ecto.Enum, values: [:authorized, :posted, :cancelled, :rejected]
    field :reason, :string
    field :authorized_at, :utc_datetime_usec
    field :settled_at, :utc_datetime_usec
  end
end
