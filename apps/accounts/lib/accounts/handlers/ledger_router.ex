defmodule Accounts.Handlers.LedgerRouter do
  @moduledoc """
  The transfer saga of README section 5, as a policy on the event store.

  Each event carries the other account of its transfer, so the saga needs no state of its own
  per `transfer_id`: every step follows from the event alone.

    * `BalanceReserved` asks the destination to authorize the credit (README, D5).
    * `CreditRejected` releases the source's reservation.
    * `CreditAuthorized` is booked in the Ledger by `LedgerCommandsPublisher`, the outbox, and
      the Ledger's answer comes back through RabbitMQ (D3).

  The commands are idempotent by `transfer_id` (D4), so an event handled twice is harmless.
  """

  use Commanded.Event.Handler,
    application: Accounts.App,
    name: "ledger_router",
    start_from: :origin

  alias Accounts.App
  alias Accounts.BankAccounts
  alias Accounts.Commands.AuthorizeCredit
  alias Accounts.Commands.ReleaseBalance
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CreditRejected
  alias Commanded.Event.FailureContext

  @max_retry_delay :timer.minutes(5)

  @impl Commanded.Event.Handler
  def handle(event, _metadata) do
    event
    |> commands_for()
    |> Enum.reduce_while(:ok, fn command, :ok ->
      case App.dispatch(command) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  # A reservation recorded before reservations named their destination: no saga can finish it,
  # so it is released rather than holding the balance forever (README, D6).
  def commands_for(%BalanceReserved{to_account_id: nil} = event) do
    [%ReleaseBalance{account_id: event.account_id, transfer_id: event.transfer_id}]
  end

  def commands_for(%BalanceReserved{} = event) do
    [
      %AuthorizeCredit{
        account_id: event.to_account_id,
        amount: event.amount,
        transfer_id: event.transfer_id,
        from_account_id: event.account_id
      }
    ]
  end

  # A credit from a bank account, such as an inbound PIX, reserved nothing to release, and neither
  # did one recorded before credits named their source.
  def commands_for(%CreditRejected{} = event) do
    if event.from_account_id == nil or BankAccounts.bank_account?(event.from_account_id) do
      []
    else
      [%ReleaseBalance{account_id: event.from_account_id, transfer_id: event.transfer_id}]
    end
  end

  def commands_for(_event), do: []

  # A failed dispatch is retried with a growing delay and never skipped: the subscription does
  # not move past an event until the saga took its next step.
  @impl Commanded.Event.Handler
  def error(_error, _event, %FailureContext{context: context} = failure_context) do
    failures = Map.get(context, :failures, 0) + 1
    delay = min(failures * failures * 1_000, @max_retry_delay)

    {:retry, delay, %{failure_context | context: Map.put(context, :failures, failures)}}
  end
end
