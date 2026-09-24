defmodule Accounts.Events.CreditCancelled do
  @moduledoc """
  An authorized credit was dropped: its batch was rejected and nothing reached the account.
  """

  defstruct [:account_id, :correlation_id, :amount]
end
