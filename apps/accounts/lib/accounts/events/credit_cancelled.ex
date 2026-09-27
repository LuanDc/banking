defmodule Accounts.Events.CreditCancelled do
  @moduledoc """
  An authorized credit was dropped: its batch was rejected and nothing reached the account.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :transfer_id, :amount]
end
