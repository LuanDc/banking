defmodule AccountsWeb.TransferJSON do
  def show(%{transfer: transfer}), do: transfer

  def deposit(%{deposit: deposit}), do: deposit
end
