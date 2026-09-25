defmodule AccountsWeb.LifecycleController do
  @moduledoc """
  Back-office transitions of the account FSM (README, section 3.1). Each one answers 204: the
  read models follow shortly after.
  """

  use AccountsWeb, :controller

  alias Accounts.CustomerAccounts

  action_fallback AccountsWeb.FallbackController

  def activate(conn, params),
    do: respond(conn, CustomerAccounts.activate_customer_account(params))

  def block(conn, params), do: respond(conn, CustomerAccounts.block_customer_account(params))
  def unblock(conn, params), do: respond(conn, CustomerAccounts.unblock_customer_account(params))
  def freeze(conn, params), do: respond(conn, CustomerAccounts.freeze_customer_account(params))

  def unfreeze(conn, params),
    do: respond(conn, CustomerAccounts.unfreeze_customer_account(params))

  def close(conn, params), do: respond(conn, CustomerAccounts.close_customer_account(params))

  defp respond(conn, :ok), do: send_resp(conn, :no_content, "")
  defp respond(_conn, error), do: error
end
