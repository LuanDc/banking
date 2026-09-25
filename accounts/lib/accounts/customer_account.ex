defmodule Accounts.CustomerAccount do
  @moduledoc """
  Aggregate guarding a customer account's lifecycle, modeled as an FSM.
  """

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.AuthorizeCredit
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CancelCredit
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.ConfirmReservation
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.PostCredit
  alias Accounts.Commands.ReleaseBalance
  alias Accounts.Commands.ReserveBalance
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  alias Accounts.Events.BalanceReleased
  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CreditCancelled
  alias Accounts.Events.CreditPosted
  alias Accounts.Events.CreditRejected
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked
  alias Accounts.Events.CustomerAccountUnfrozen
  alias Accounts.Events.ReservationConfirmed

  defstruct [
    :account_id,
    :status,
    available_balance: 0,
    reservations: %{},
    pending_credits: %{},
    posted_credits: MapSet.new()
  ]

  # Debit and credit columns of the matrix (README, section 3.1).
  @can_send [:active]
  @can_receive [:active, :blocked]

  # The lifecycle FSM (README, sections 3.1 and 7): {from, event} => to.
  # execute/2 emits an event only when it is a transition out of the current
  # status, and apply/2 follows that same transition to the next status.
  @transitions %{
    {nil, CustomerAccountOpened} => :pending_kyc,
    {:pending_kyc, CustomerAccountActivated} => :active,
    {:active, CustomerAccountBlocked} => :blocked,
    {:blocked, CustomerAccountUnblocked} => :active,
    {:active, CustomerAccountFrozen} => :frozen,
    {:frozen, CustomerAccountUnfrozen} => :active,
    {:active, CustomerAccountClosed} => :closed,
    {:blocked, CustomerAccountClosed} => :closed
  }

  @lifecycle_events @transitions |> Map.keys() |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

  def execute(%__MODULE__{status: nil}, %OpenCustomerAccount{} = command) do
    %CustomerAccountOpened{account_id: command.account_id, customer_id: command.customer_id}
  end

  def execute(%__MODULE__{}, %OpenCustomerAccount{}), do: {:error, :account_already_exists}

  def execute(%__MODULE__{} = account, %ActivateCustomerAccount{} = command) do
    transition(account, %CustomerAccountActivated{account_id: command.account_id})
  end

  def execute(%__MODULE__{} = account, %BlockCustomerAccount{} = command) do
    transition(account, %CustomerAccountBlocked{
      account_id: command.account_id,
      reason: command.reason
    })
  end

  def execute(%__MODULE__{} = account, %UnblockCustomerAccount{} = command) do
    transition(account, %CustomerAccountUnblocked{account_id: command.account_id})
  end

  def execute(%__MODULE__{} = account, %FreezeCustomerAccount{} = command) do
    transition(account, %CustomerAccountFrozen{
      account_id: command.account_id,
      reason: command.reason
    })
  end

  def execute(%__MODULE__{} = account, %UnfreezeCustomerAccount{} = command) do
    transition(account, %CustomerAccountUnfrozen{account_id: command.account_id})
  end

  def execute(%__MODULE__{} = account, %CloseCustomerAccount{} = command) do
    event = %CustomerAccountClosed{account_id: command.account_id}

    with :ok <- check_transition(account, event),
         :ok <- check_closure(account) do
      event
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

  def execute(%__MODULE__{} = account, %AuthorizeCredit{} = command) do
    case check_credit(account, command.amount) do
      :ok ->
        %CreditAuthorized{
          account_id: command.account_id,
          amount: command.amount,
          correlation_id: command.correlation_id
        }

      {:error, reason} ->
        %CreditRejected{
          account_id: command.account_id,
          amount: command.amount,
          correlation_id: command.correlation_id,
          reason: reason
        }
    end
  end

  def execute(%__MODULE__{} = account, %PostCredit{} = command) do
    # README, D4: a redelivered credit is posted only once.
    if MapSet.member?(account.posted_credits, command.correlation_id) do
      []
    else
      %CreditPosted{
        account_id: command.account_id,
        amount: command.amount,
        correlation_id: command.correlation_id
      }
    end
  end

  # README, D4: a redelivered cancellation for a settled credit does nothing.
  def execute(%__MODULE__{pending_credits: pending}, %CancelCredit{correlation_id: id})
      when not is_map_key(pending, id),
      do: []

  def execute(%__MODULE__{} = account, %CancelCredit{} = command) do
    %CreditCancelled{
      account_id: command.account_id,
      correlation_id: command.correlation_id,
      amount: Map.fetch!(account.pending_credits, command.correlation_id)
    }
  end

  def apply(%__MODULE__{} = account, %CustomerAccountOpened{} = event) do
    %__MODULE__{account | account_id: event.account_id, status: next_status!(account, event)}
  end

  def apply(%__MODULE__{} = account, %event{} = lifecycle_event)
      when event in @lifecycle_events do
    %__MODULE__{account | status: next_status!(account, lifecycle_event)}
  end

  def apply(%__MODULE__{} = account, %BalanceReserved{} = event) do
    %__MODULE__{
      account
      | available_balance: account.available_balance - event.amount,
        reservations: Map.put(account.reservations, event.correlation_id, event.amount)
    }
  end

  def apply(%__MODULE__{} = account, %BalanceReservationRejected{}), do: account

  def apply(%__MODULE__{} = account, %CreditAuthorized{} = event) do
    %__MODULE__{
      account
      | pending_credits: Map.put(account.pending_credits, event.correlation_id, event.amount)
    }
  end

  def apply(%__MODULE__{} = account, %CreditRejected{}), do: account

  def apply(%__MODULE__{} = account, %CreditCancelled{} = event) do
    %__MODULE__{
      account
      | pending_credits: Map.delete(account.pending_credits, event.correlation_id)
    }
  end

  def apply(%__MODULE__{} = account, %CreditPosted{} = event) do
    %__MODULE__{
      account
      | available_balance: account.available_balance + event.amount,
        pending_credits: Map.delete(account.pending_credits, event.correlation_id),
        posted_credits: MapSet.put(account.posted_credits, event.correlation_id)
    }
  end

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

  defp check_reservation(account, amount) do
    cond do
      not valid_amount?(amount) -> {:error, :invalid_amount}
      account.status not in @can_send -> {:error, :account_not_active}
      amount > account.available_balance -> {:error, :insufficient_balance}
      true -> :ok
    end
  end

  # README, H6: an account closes empty.
  defp check_closure(account) do
    cond do
      account.available_balance > 0 -> {:error, :balance_not_zero}
      map_size(account.reservations) > 0 -> {:error, :open_reservations}
      map_size(account.pending_credits) > 0 -> {:error, :pending_credits}
      true -> :ok
    end
  end

  defp check_credit(account, amount) do
    cond do
      not valid_amount?(amount) -> {:error, :invalid_amount}
      account.status not in @can_receive -> {:error, :credit_not_allowed}
      true -> :ok
    end
  end

  # README, D1: money is an integer number of cents.
  defp valid_amount?(amount), do: is_integer(amount) and amount > 0

  defp transition(account, event) do
    with :ok <- check_transition(account, event), do: event
  end

  defp check_transition(%__MODULE__{status: from}, %event{}) do
    if is_map_key(@transitions, {from, event}), do: :ok, else: {:error, :invalid_transition}
  end

  # An event stored in the stream was a valid transition when emitted, so a
  # missing entry here means a corrupt stream and should crash the aggregate.
  defp next_status!(%__MODULE__{status: from}, %event{}) do
    Map.fetch!(@transitions, {from, event})
  end
end
