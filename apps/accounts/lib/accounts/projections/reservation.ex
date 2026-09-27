defmodule Accounts.Projections.Reservation do
  @moduledoc """
  Read model of every balance reservation and how it settled, the ReservationsView (README,
  section 7).
  """

  use Ecto.Schema

  schema "reservations" do
    field :account_id, :string
    field :transfer_id, :string
    field :to_account_id, :string
    field :amount, :integer
    field :status, Ecto.Enum, values: [:open, :confirmed, :released, :rejected]
    field :reason, :string
    field :reserved_at, :utc_datetime_usec
    field :settled_at, :utc_datetime_usec
  end
end
