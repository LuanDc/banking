defmodule Accounts.CustomerAccount do
  @moduledoc """
  Aggregate guarding a customer account's lifecycle, modeled as an FSM.
  """

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.ConfirmReservation
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.ReleaseBalance
  alias Accounts.Commands.ReserveBalance
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  alias Accounts.Events.BalanceReleased
  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked
  alias Accounts.Events.CustomerAccountUnfrozen
  alias Accounts.Events.ReservationConfirmed

  defstruct [:account_id, :status, available_balance: 0, reservations: %{}]

  # Statuses each command may run from (README, sections 3.1 and 7).
  # The status it leads to is set by the event's apply/2.
  @allowed_from %{
    ActivateCustomerAccount => [:pending_kyc],
    BlockCustomerAccount => [:active],
    UnblockCustomerAccount => [:blocked],
    FreezeCustomerAccount => [:active],
    UnfreezeCustomerAccount => [:frozen],
    CloseCustomerAccount => [:active, :blocked]
  }

  def execute(%__MODULE__{status: nil}, %OpenCustomerAccount{} = command) do
    %CustomerAccountOpened{account_id: command.account_id, customer_id: command.customer_id}
  end

  def execute(%__MODULE__{}, %OpenCustomerAccount{}), do: {:error, :account_already_exists}

  def execute(%__MODULE__{status: status}, %ActivateCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountActivated{account_id: command.account_id}
    end
  end

  def execute(%__MODULE__{status: status}, %BlockCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountBlocked{account_id: command.account_id, reason: command.reason}
    end
  end

  def execute(%__MODULE__{status: status}, %UnblockCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountUnblocked{account_id: command.account_id}
    end
  end

  def execute(%__MODULE__{status: status}, %FreezeCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountFrozen{account_id: command.account_id, reason: command.reason}
    end
  end

  def execute(%__MODULE__{status: status}, %UnfreezeCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountUnfrozen{account_id: command.account_id}
    end
  end

  def execute(%__MODULE__{status: status}, %CloseCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountClosed{account_id: command.account_id}
    end
  end

  # README, D4: a repeated command for an open reservation reserves nothing.
  def execute(%__MODULE__{reservations: reservations}, %ReserveBalance{correlation_id: id})
      when is_map_key(reservations, id),
      do: []

  def execute(%__MODULE__{} = account, %ReserveBalance{} = command) do
    case check_reservation(account, command.amount) do
      :ok ->
        %BalanceReserved{
          account_id: command.account_id,
          amount: command.amount,
          correlation_id: command.correlation_id
        }

      {:error, reason} ->
        %BalanceReservationRejected{
          account_id: command.account_id,
          amount: command.amount,
          correlation_id: command.correlation_id,
          reason: reason
        }
    end
  end

  # README, D4: a redelivered confirmation for a settled reservation does nothing.
  def execute(%__MODULE__{reservations: reservations}, %ConfirmReservation{correlation_id: id})
      when not is_map_key(reservations, id),
      do: []

  def execute(%__MODULE__{} = account, %ConfirmReservation{} = command) do
    %ReservationConfirmed{
      account_id: command.account_id,
      correlation_id: command.correlation_id,
      amount: Map.fetch!(account.reservations, command.correlation_id)
    }
  end

  # README, D4: a redelivered release for a closed reservation gives nothing back twice.
  def execute(%__MODULE__{reservations: reservations}, %ReleaseBalance{correlation_id: id})
      when not is_map_key(reservations, id),
      do: []

  def execute(%__MODULE__{} = account, %ReleaseBalance{} = command) do
    %BalanceReleased{
      account_id: command.account_id,
      correlation_id: command.correlation_id,
      amount: Map.fetch!(account.reservations, command.correlation_id)
    }
  end

  def apply(%__MODULE__{} = account, %CustomerAccountOpened{} = event) do
    %__MODULE__{account | account_id: event.account_id, status: :pending_kyc}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountActivated{}) do
    %__MODULE__{account | status: :active}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountBlocked{}) do
    %__MODULE__{account | status: :blocked}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountUnblocked{}) do
    %__MODULE__{account | status: :active}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountFrozen{}) do
    %__MODULE__{account | status: :frozen}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountUnfrozen{}) do
    %__MODULE__{account | status: :active}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountClosed{}) do
    %__MODULE__{account | status: :closed}
  end

  def apply(%__MODULE__{} = account, %BalanceReserved{} = event) do
    %__MODULE__{
      account
      | available_balance: account.available_balance - event.amount,
        reservations: Map.put(account.reservations, event.correlation_id, event.amount)
    }
  end

  def apply(%__MODULE__{} = account, %BalanceReservationRejected{}), do: account

  def apply(%__MODULE__{} = account, %ReservationConfirmed{} = event) do
    %__MODULE__{account | reservations: Map.delete(account.reservations, event.correlation_id)}
  end

  def apply(%__MODULE__{} = account, %BalanceReleased{} = event) do
    %__MODULE__{
      account
      | available_balance: account.available_balance + event.amount,
        reservations: Map.delete(account.reservations, event.correlation_id)
    }
  end

  # README, section 3.1: only an ACTIVE account may send money.
  defp check_reservation(account, amount) do
    cond do
      not valid_amount?(amount) -> {:error, :invalid_amount}
      account.status != :active -> {:error, :account_not_active}
      amount > account.available_balance -> {:error, :insufficient_balance}
      true -> :ok
    end
  end

  # README, D1: money is an integer number of cents.
  defp valid_amount?(amount), do: is_integer(amount) and amount > 0

  defp guard(status, %command{}) do
    if status in Map.fetch!(@allowed_from, command), do: :ok, else: {:error, :invalid_transition}
  end
end
