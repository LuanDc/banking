defmodule E2E.Flows do
  @moduledoc """
  The steps a story is told with: open and fund accounts, wait for a transfer, check both books.

  They drive the running services through the public API only (D15) and wait through
  `eventually/2`, so a failed step raises the last assertion. The stories import them through
  `E2E.StoryCase`, and the load test sets up its accounts and checks the books with the same
  ones (`E2E.Load`).
  """

  import E2E.Eventually
  import ExUnit.Assertions

  alias E2E.Accounts
  alias E2E.Ledger

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

  @spec assert_status(String.t(), String.t()) :: Req.Response.t()
  def assert_status(account_id, status) do
    assert %{status: 200, body: %{"status" => ^status}} = Accounts.get_account(account_id)
  end

  @doc """
  Asserts the same balance in both books: the available balance in Accounts and the ledger
  balance in the Ledger (docs, D2). They match whenever no transfer is in flight.
  """
  @spec assert_balance(String.t(), integer()) :: Req.Response.t()
  def assert_balance(account_id, amount) do
    assert %{status: 200, body: %{"available_balance" => ^amount}} =
             Accounts.get_account(account_id)

    assert %{status: 200, body: %{"balance" => ^amount}} = Ledger.balance(account_id)
  end
end
