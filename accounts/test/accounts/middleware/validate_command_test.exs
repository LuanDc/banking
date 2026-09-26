defmodule Accounts.Middleware.ValidateCommandTest do
  use ExUnit.Case, async: true

  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Middleware.ValidateCommand
  alias Commanded.Middleware.Pipeline

  test "lets a valid command through to its aggregate" do
    pipeline = %Pipeline{command: %BlockCustomerAccount{account_id: "acc-1", reason: "fraud"}}

    assert ValidateCommand.before_dispatch(pipeline) == pipeline
  end

  test "stops an invalid command and answers with its fields' messages" do
    pipeline = %Pipeline{command: %BlockCustomerAccount{account_id: "acc-1"}}

    pipeline = ValidateCommand.before_dispatch(pipeline)

    assert Pipeline.halted?(pipeline)

    assert Pipeline.response(pipeline) ==
             {:error, {:validation_failed, %{reason: ["must be present"]}}}
  end
end
