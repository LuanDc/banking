defmodule Ledger.Factory do
  @moduledoc """
  ExMachina factories for tests.

  Define factories as `<name>_factory/0` functions, e.g.:

      def account_factory do
        %Ledger.Accounts.Account{
          name: Faker.Person.name(),
          currency: "BRL"
        }
      end

  Then use `insert(:account)`, `build(:account)` or `params_for(:account)`.
  """

  use ExMachina.Ecto, repo: Ledger.Repo
end
