defmodule Accounts.App do
  @moduledoc """
  Commanded application: the entry point for dispatching commands.

  Named `App` rather than `Application` so it does not clash with
  `Accounts.Application`, the OTP application callback module.
  """

  use Commanded.Application, otp_app: :accounts
end
