defmodule Accounts.Events.CustomerAccountClosed do
  @moduledoc """
  A customer account was closed. Closing is terminal: no command applies afterwards.
  """

  @derive Jason.Encoder
  defstruct [:account_id]
end
