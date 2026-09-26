defmodule Ledger.RouterTest do
  use ExUnit.Case, async: true

  test "routes every command module" do
    {:ok, modules} = :application.get_key(:ledger, :modules)

    commands =
      Enum.filter(modules, &String.starts_with?(Atom.to_string(&1), "Elixir.Ledger.Commands."))

    assert commands != []
    assert Enum.sort(commands) == Enum.sort(Ledger.Router.__registered_commands__())
  end
end
