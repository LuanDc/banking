defmodule Accounts.Factory do
  @moduledoc """
  ExMachina factories for the read models, so API tests can read rows without replaying events.

  Use `insert(:customer_account)`, `build(:reservation)` or `params_for(:credit)`.
  """

  use ExMachina.Ecto, repo: Accounts.Repo

  alias Accounts.Projections.Credit
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.Reservation
  alias Accounts.Projections.StatusChange

  def customer_account_factory do
    now = DateTime.utc_now()

    %CustomerAccount{
      account_id: Ecto.UUID.generate(),
      customer_id: Ecto.UUID.generate(),
      status: :active,
      available_balance: 1_000,
      opened_at: now,
      updated_at: now
    }
  end

  def status_change_factory do
    %StatusChange{
      account_id: Ecto.UUID.generate(),
      event: "CustomerAccountOpened",
      status: :pending_kyc,
      occurred_at: DateTime.utc_now()
    }
  end

  def reservation_factory do
    %Reservation{
      account_id: Ecto.UUID.generate(),
      correlation_id: sequence(:correlation_id, &"corr-#{&1}"),
      amount: 400,
      status: :open,
      reserved_at: DateTime.utc_now()
    }
  end

  def credit_factory do
    %Credit{
      account_id: Ecto.UUID.generate(),
      correlation_id: sequence(:correlation_id, &"corr-#{&1}"),
      amount: 400,
      status: :authorized,
      authorized_at: DateTime.utc_now()
    }
  end
end
