defmodule E2E.StoryCase do
  @moduledoc """
  Case template for a story: a scenario told through the public API only.

  Each story creates its own customers and keys, so stories run concurrently against the same
  running services and never depend on each other's data.
  """

  use ExUnit.CaseTemplate

  import E2E.Eventually
  import ExUnit.Assertions

  alias E2E.Accounts
  alias E2E.Ledger

  using do
    quote do
      import E2E.Eventually
      import E2E.StoryCase

      alias E2E.Accounts
      alias E2E.Broker
      alias E2E.Ledger
    end
  end

  @doc "A fresh id for a customer or an `Idempotency-Key`."
  @spec new_key(String.t()) :: String.t()
  def new_key(prefix \\ "e2e") do
    "#{prefix}-#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  end

  @doc "Opens an account and activates it, as KYC would, and waits until it shows as active."
  @spec active_account() :: String.t()
  def active_account do
    %{status: 201, body: %{"account_id" => account_id}} =
      Accounts.open_account(new_key("customer"))

    %{status: 204} = Accounts.transition(account_id, "activate")
    eventually(fn -> assert_status(account_id, "active") end)
    account_id
  end

  @doc "An active account holding `amount` cents, received as an inbound PIX."
  @spec funded_account(pos_integer()) :: String.t()
  def funded_account(amount) do
    account_id = active_account()
    %{status: 202} = Accounts.deposit(account_id, amount, new_key("deposit"))
    eventually(fn -> assert_balance(account_id, amount) end)
    account_id
  end

  @doc "Waits for a transfer's outcome and returns the transfer."
  @spec settled_transfer(String.t(), String.t()) :: map()
  def settled_transfer(correlation_id, status) do
    eventually(fn ->
      assert %{status: 200, body: %{"status" => ^status} = transfer} =
               Accounts.get_transfer(correlation_id)

      transfer
    end)
  end

  @spec assert_status(String.t(), String.t()) :: true
  def assert_status(account_id, status) do
    assert %{status: 200, body: %{"status" => ^status}} = Accounts.get_account(account_id)
  end

  @doc """
  Asserts the same balance in both books: the available balance in Accounts and the ledger
  balance in the Ledger (docs, D2). They match whenever no transfer is in flight.
  """
  @spec assert_balance(String.t(), integer()) :: true
  def assert_balance(account_id, amount) do
    assert %{status: 200, body: %{"available_balance" => ^amount}} =
             Accounts.get_account(account_id)

    assert %{status: 200, body: %{"balance" => ^amount}} = Ledger.balance(account_id)
  end
end
