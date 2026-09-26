defmodule Accounts.RouterTest do
  use ExUnit.Case, async: true

  test "routes every command module" do
    {:ok, modules} = :application.get_key(:accounts, :modules)

    commands =
      Enum.filter(modules, &String.starts_with?(Atom.to_string(&1), "Elixir.Accounts.Commands."))

    assert commands != []
    assert Enum.sort(commands) == Enum.sort(Accounts.Router.__registered_commands__())
  end
end
