defmodule Accounts.Events.CustomerAccountOpened do
  @moduledoc """
  A customer account was opened.
  """

  defstruct [:account_id, :customer_id]
end
