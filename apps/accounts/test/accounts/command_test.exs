defmodule Accounts.CommandTest do
  # The input rules each command declares (README, D14): what a command must carry before it is
  # dispatched. The business rules stay in the aggregate.
  use ExUnit.Case, async: true

  alias Accounts.Command
  alias Accounts.Commands

  describe "validate/1" do
    test "accepts a well-formed command" do
      command = %Commands.ReserveBalance{
        account_id: "acc-1",
        amount: 400,
        transfer_id: "corr-1",
        to_account_id: "acc-2"
      }

      assert Command.validate(command) == :ok
    end

    test "every command names its account" do
      for module <- [
            Commands.OpenCustomerAccount,
            Commands.ActivateCustomerAccount,
            Commands.BlockCustomerAccount,
            Commands.UnblockCustomerAccount,
            Commands.FreezeCustomerAccount,
            Commands.UnfreezeCustomerAccount,
            Commands.CloseCustomerAccount,
            Commands.ReserveBalance,
            Commands.ConfirmReservation,
            Commands.ReleaseBalance,
            Commands.AuthorizeCredit,
            Commands.PostCredit,
            Commands.CancelCredit
          ] do
        assert {:error, {:validation_failed, %{account_id: ["must be present"]}}} =
                 Command.validate(struct(module))
      end
    end

    test "an account opens for a customer" do
      assert invalid(%Commands.OpenCustomerAccount{account_id: "acc-1", customer_id: ""}) ==
               %{customer_id: ["must be present"]}
    end

    test "blocking and freezing are explained" do
      for module <- [Commands.BlockCustomerAccount, Commands.FreezeCustomerAccount] do
        assert invalid(struct(module, account_id: "acc-1")) == %{reason: ["must be present"]}
      end
    end

    test "a saga step carries its correlation id (README, D4)" do
      for module <- [
            Commands.ReserveBalance,
            Commands.ConfirmReservation,
            Commands.ReleaseBalance,
            Commands.AuthorizeCredit,
            Commands.PostCredit,
            Commands.CancelCredit
          ] do
        assert %{transfer_id: ["must be present"]} = invalid(struct(module, account_id: "a"))
      end
    end

    test "an amount is a positive integer number of cents (README, D1)" do
      for amount <- [nil, 0, -100, 10.5, "400"],
          module <- [Commands.ReserveBalance, Commands.AuthorizeCredit, Commands.PostCredit] do
        command = struct(module, account_id: "acc-1", transfer_id: "corr-1", amount: amount)

        assert %{amount: ["must be a positive integer number of cents"]} = invalid(command)
      end
    end

    test "a transfer goes to another account" do
      base = %Commands.ReserveBalance{account_id: "acc-1", amount: 400, transfer_id: "corr-1"}

      assert invalid(base) == %{to_account_id: ["must be present"]}

      assert invalid(%{base | to_account_id: "acc-1"}) ==
               %{to_account_id: ["must be another account"]}
    end

    test "a credit names where the money comes from" do
      command = %Commands.AuthorizeCredit{account_id: "acc-1", amount: 400, transfer_id: "c"}

      assert invalid(command) == %{from_account_id: ["must be present"]}
    end
  end

  defp invalid(command) do
    {:error, {:validation_failed, fields}} = Command.validate(command)
    fields
  end
end
