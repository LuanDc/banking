defmodule Accounts.Messaging.LedgerEventsInboxTest do
  use ExUnit.Case, async: true

  alias Accounts.BankAccounts
  alias Accounts.Commands.CancelCredit
  alias Accounts.Commands.ConfirmReservation
  alias Accounts.Commands.PostCredit
  alias Accounts.Commands.ReleaseBalance
  alias Accounts.Messaging.LedgerEventsInbox

  # Messages arrive as decoded JSON: string keys, string values.
  @entries [
    %{"account_id" => "acc-1", "type" => "debit", "amount" => 400},
    %{"account_id" => "acc-2", "type" => "credit", "amount" => 400}
  ]

  describe "to_commands/1" do
    test "a booked batch confirms the debited reservation and posts the credit (README, section 5)" do
      message = booked(@entries)

      assert LedgerEventsInbox.to_commands(message) ==
               {:ok,
                [
                  %ConfirmReservation{account_id: "acc-1", transfer_id: "corr-1"},
                  %PostCredit{account_id: "acc-2", amount: 400, transfer_id: "corr-1"}
                ]}
    end

    test "a rejected batch releases the reservation and cancels the pending credit" do
      message = %{
        "type" => "LedgerBatchRejected",
        "payload" => %{
          "batch_id" => "corr-1",
          "correlation_id" => "corr-1",
          "reason" => "account_not_open",
          "entries" => @entries
        }
      }

      assert LedgerEventsInbox.to_commands(message) ==
               {:ok,
                [
                  %ReleaseBalance{account_id: "acc-1", transfer_id: "corr-1"},
                  %CancelCredit{account_id: "acc-2", transfer_id: "corr-1"}
                ]}
    end

    test "leaves out the bank's accounts, which are not customer accounts" do
      message =
        booked([
          %{"account_id" => BankAccounts.pix_settlement(), "type" => "debit", "amount" => 400},
          %{"account_id" => "acc-2", "type" => "credit", "amount" => 400}
        ])

      assert LedgerEventsInbox.to_commands(message) ==
               {:ok, [%PostCredit{account_id: "acc-2", amount: 400, transfer_id: "corr-1"}]}
    end

    test "fails an event it does not know" do
      assert {:error, :unknown_event} =
               LedgerEventsInbox.to_commands(%{"type" => "LedgerBatchReversed", "payload" => %{}})
    end
  end

  defp booked(entries) do
    %{
      "type" => "LedgerBatchBooked",
      "payload" => %{"batch_id" => "corr-1", "correlation_id" => "corr-1", "entries" => entries}
    }
  end
end
