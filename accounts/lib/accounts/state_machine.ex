defmodule Accounts.StateMachine do
  @moduledoc """
  Allowed status transitions of a customer account (README, section 3.1).
  """

  @transitions %{
    pending_kyc: [:active],
    active: [:blocked]
  }

  def transition(from, to) do
    if to in Map.get(@transitions, from, []), do: :ok, else: {:error, :invalid_transition}
  end
end
