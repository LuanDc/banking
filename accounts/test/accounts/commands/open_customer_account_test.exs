defmodule Accounts.Commands.OpenCustomerAccountTest do
  use ExUnit.Case, async: true

  alias Accounts.Commands.OpenCustomerAccount

  describe "generate_uuid/1" do
    test "gives the account a new UUID, whatever id it came with" do
      command =
        OpenCustomerAccount.new(%{"account_id" => "chosen-by-client", "customer_id" => "c"})

      assert %OpenCustomerAccount{account_id: id, customer_id: "c"} =
               OpenCustomerAccount.generate_uuid(command)

      assert {:ok, ^id} = Ecto.UUID.cast(id)
    end
  end
end
