defmodule Accounts.Factory do
  @moduledoc """
  ExMachina factories for tests.

  Define factories as `<name>_factory/0` functions, e.g.:

      def account_factory do
        %Accounts.Customer{
          name: Faker.Person.name(),
          currency: "BRL"
        }
      end

  Then use `insert(:account)`, `build(:account)` or `params_for(:account)`.
  """

  use ExMachina.Ecto, repo: Accounts.Repo
end
