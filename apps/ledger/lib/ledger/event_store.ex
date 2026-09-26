defmodule Ledger.EventStore do
  @moduledoc """
  Postgres-backed event store, the write side's source of truth.

  It lives in its own database, separate from `Ledger.Repo`, which holds the
  read models. Schema management is done through `mix event_store.*` tasks,
  not through Ecto migrations.
  """

  use EventStore, otp_app: :ledger
end
