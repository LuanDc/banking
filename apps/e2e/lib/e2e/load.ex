defmodule E2E.Load do
  @moduledoc """
  A load test told with the stories' own steps: the same clients, the same `E2E.Flows`, the same
  check that both books agree (D2), under a steady stream of customers.

  1. **Setup**, not measured: opens a pool of funded accounts with `E2E.Flows.funded_account/1`.
  2. **Load**: starts operations at a fixed rate (an open model, `E2E.Load.Workload`), each on
     its own process, and times two things per operation:
     - *accept*: the request until its answer (`202` for a transfer or a deposit);
     - *settle*: the request until the outcome shows in the read model, polled every `poll` ms.
       A transfer crosses RabbitMQ twice, so this is where a backlog shows first.

     While it runs, it samples the RabbitMQ queues every second, for the backlog.
  3. **Check**: waits for what timed out, then asserts that every account ends with the balance
     its outcomes add up to (`E2E.Load.Books`) in both books, that the trial balance holds, and
     that no message was dead-lettered.

  The polling is part of the load: a client that wants to know the outcome has to ask.
  """

  import E2E.Eventually

  alias E2E.Accounts
  alias E2E.Flows
  alias E2E.Ledger
  alias E2E.Load.Books
  alias E2E.Load.Stats
  alias E2E.Load.Workload
  alias E2E.RabbitMQ

  @defaults [
    rate: 20,
    duration: 30,
    accounts: 20,
    weights: [transfer: 80, deposit: 15, read: 5],
    balance: 1_000_000,
    poll: 100,
    settle_timeout: 30,
    drain_timeout: 120,
    max_in_flight: 2_000
  ]

  @operations [:transfer, :deposit, :read]

  @doc "The options `run/1` starts from."
  @spec defaults() :: keyword()
  def defaults, do: @defaults

  @doc """
  Runs the load test and returns its report. Options (the defaults are in `defaults/0`):

    * `:rate` - operations started per second
    * `:duration` - seconds of load
    * `:accounts` - accounts in the pool, each funded with `:balance` cents
    * `:weights` - the mix, e.g. `[transfer: 80, deposit: 15, read: 5]`
    * `:poll` - ms between two reads while waiting for an outcome
    * `:settle_timeout` - seconds an operation waits for its outcome during the load
    * `:drain_timeout` - seconds the check waits for late outcomes and for the balances
    * `:max_in_flight` - operations running at once; a start past it is dropped and counted
  """
  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    opts =
      @defaults
      |> Keyword.merge(opts)
      |> Map.new()

    dead_letters_before = dead_letters()
    initial = open_accounts(opts)
    accounts = Map.keys(initial)

    sampler = start_sampler()
    started = now()
    {results, dropped, lags} = drive(accounts, opts)
    elapsed_ms = now() - started
    backlog = stop_sampler(sampler)

    results = resolve_late(results, opts)

    %{
      config: config(opts),
      sent: length(results),
      dropped: dropped,
      elapsed_ms: elapsed_ms,
      generator_lag: Stats.summary(lags),
      operations: Map.new(@operations, &{&1, operation_report(results, &1, opts)}),
      backlog: backlog,
      consistency: check(initial, results, dead_letters_before, opts)
    }
  end

  ## Setup

  defp open_accounts(opts) do
    1..opts.accounts
    |> Task.async_stream(fn _ -> Flows.funded_account(opts.balance) end,
      max_concurrency: 10,
      timeout: :infinity
    )
    |> Map.new(fn {:ok, account_id} -> {account_id, opts.balance} end)
  end

  ## Load

  defp drive(accounts, opts) do
    {:ok, supervisor} = Task.Supervisor.start_link()
    in_flight = :counters.new(1, [:atomics])
    start = now()

    {tasks, dropped, lags} =
      opts.rate
      |> Workload.arrivals(opts.duration)
      |> Enum.zip(Workload.plan(opts.weights, opts.rate * opts.duration))
      |> Enum.reduce({[], 0, []}, fn {at, operation}, {tasks, dropped, lags} ->
        Process.sleep(max(start + at - now(), 0))
        lags = [now() - (start + at) | lags]

        case start(operation, supervisor, in_flight, accounts, opts) do
          {:ok, task} -> {[task | tasks], dropped, lags}
          :dropped -> {tasks, dropped + 1, lags}
        end
      end)

    results =
      tasks
      |> Enum.reverse()
      |> Task.yield_many(timeout: opts.settle_timeout * 1_000 + 30_000)
      |> Enum.map(fn
        {_task, {:ok, result}} -> result
        {_task, {:exit, reason}} -> %{op: :unknown, outcome: "error", reason: inspect(reason)}
        {task, nil} -> no_answer(task)
      end)

    {results, dropped, lags}
  end

  # Past `max_in_flight`, the generator would only queue work it cannot send in time.
  defp start(operation, supervisor, in_flight, accounts, opts) do
    if :counters.get(in_flight, 1) >= opts.max_in_flight do
      :dropped
    else
      :counters.add(in_flight, 1, 1)

      {:ok,
       Task.Supervisor.async_nolink(supervisor, fn ->
         try do
           operate(operation, accounts, opts)
         after
           :counters.sub(in_flight, 1, 1)
         end
       end)}
    end
  end

  defp no_answer(task) do
    Task.shutdown(task, :brutal_kill)
    %{op: :unknown, outcome: "error", reason: "no answer"}
  end

  # The request is drawn before it is sent, so an error keeps its key and the check can send it
  # again, as a client would, to learn what became of it.
  defp operate(operation, accounts, opts) do
    request = request(operation, accounts)
    started = now()

    try do
      Map.merge(request, perform(request, opts, started))
    rescue
      exception -> Map.merge(request, %{outcome: "error", reason: reason(exception)})
    end
  end

  defp request(:transfer, accounts) do
    [from, to] = Enum.take_random(accounts, 2)
    key = Flows.new_key("load-transfer")
    %{op: :transfer, key: key, from: from, to: to, amount: Enum.random(1..100)}
  end

  defp request(:deposit, accounts) do
    key = Flows.new_key("load-deposit")
    %{op: :deposit, key: key, to: Enum.random(accounts), amount: Enum.random(1..100)}
  end

  defp request(:read, accounts), do: %{op: :read, account_id: Enum.random(accounts)}

  defp perform(%{op: op} = request, opts, started) when op in [:transfer, :deposit] do
    answered(send_request(request), request, started, opts)
  end

  defp perform(%{op: :read, account_id: account_id}, _opts, started) do
    %{status: 200} = Accounts.get_account(account_id)
    %{status: 200} = Ledger.balance(account_id)
    %{outcome: "ok", accept_ms: now() - started}
  end

  defp send_request(%{op: :transfer} = request),
    do: Accounts.transfer(request.from, request.to, request.amount, request.key)

  defp send_request(%{op: :deposit} = request),
    do: Accounts.deposit(request.to, request.amount, request.key)

  # README, D17: the service names the operation; its transfer_id is what the client follows.
  defp answered(response, request, started, opts) do
    accept_ms = now() - started

    case response do
      %{status: 202, body: %{"transfer_id" => transfer_id}} ->
        request
        |> Map.put(:transfer_id, transfer_id)
        |> lookup()
        |> await(started, opts)
        |> Map.merge(%{accept_ms: accept_ms, transfer_id: transfer_id})

      other ->
        Map.put(refused(other), :accept_ms, accept_ms)
    end
  end

  # The first sentence is enough to group errors by reason in the report. An exhausted client
  # pool is the generator's limit, not the services': the waiting requests are mostly polls.
  defp reason(exception) do
    case Exception.message(exception) do
      "Finch was unable to provide a connection" <> _rest ->
        "client pool exhausted (raise --pool-size or --poll)"

      message ->
        message
        |> String.split(". ", parts: 2)
        |> hd()
    end
  end

  defp refused(%{status: 422, body: %{"errors" => %{"code" => code}}}),
    do: %{outcome: "refused", reason: code}

  defp refused(%{status: status}), do: %{outcome: "error", reason: "HTTP #{status}"}

  # Polls until the outcome shows, or the settle timeout; the check resolves what timed out.
  defp await(outcome, started, opts) do
    case poll(outcome, started + opts.settle_timeout * 1_000, opts.poll) do
      {:done, status} -> %{outcome: status, settle_ms: now() - started}
      :pending -> %{outcome: "timeout"}
    end
  end

  defp poll(outcome, deadline, interval) do
    case outcome.() do
      {:done, status} ->
        {:done, status}

      _pending_or_absent ->
        if now() >= deadline do
          :pending
        else
          Process.sleep(interval)
          poll(outcome, deadline, interval)
        end
    end
  end

  defp transfer_outcome(transfer_id) do
    case Accounts.get_transfer(transfer_id) do
      %{status: 200, body: %{"status" => status}} when status in ["completed", "failed"] ->
        {:done, status}

      %{status: 404} ->
        :absent

      _pending ->
        :pending
    end
  end

  # An inbound PIX shows as a credit only once it is posted (D2), so until then it is absent.
  # An account's credits are listed newest first; a busy account may push an old one past the
  # first page, and it then counts as a timeout until the check finds it settled.
  defp credit_outcome(account_id, transfer_id) do
    %{status: 200, body: %{"data" => credits}} = Accounts.credits(account_id, limit: 100)

    case Enum.find(credits, &(&1["transfer_id"] == transfer_id)) do
      %{"status" => status} when status in ["posted", "rejected", "cancelled"] -> {:done, status}
      nil -> :absent
      _pending -> :pending
    end
  end

  ## Backlog

  defp start_sampler, do: Task.async(fn -> sample(%{}) end)

  defp stop_sampler(sampler) do
    send(sampler.pid, :stop)
    Task.await(sampler, 30_000)
  end

  defp sample(backlog) do
    backlog = Map.merge(backlog, queues(), fn _queue, seen, now -> max(seen, now) end)

    receive do
      :stop -> backlog
    after
      1_000 -> sample(backlog)
    end
  end

  # A failed sample only leaves a gap in the backlog; it must not stop the run.
  defp queues do
    RabbitMQ.queues()
  rescue
    _unreachable -> %{}
  end

  ## Check

  # Once the queues are empty, every outcome that was sent is final. What timed out is read
  # again. A client-side error may still have reached the service: it is sent again with the same
  # key, as a client would, and the service answers with what it already started, or starts it.
  defp resolve_late(results, opts) do
    deadline = now() + opts.drain_timeout * 1_000

    if Enum.any?(results, &(&1.outcome in ["timeout", "error"])),
      do: wait_for_empty_queues(deadline)

    Enum.map(results, fn
      %{outcome: "timeout"} = result -> resolve(result, deadline, opts)
      %{outcome: "error", key: _key} = result -> recover(result, deadline, opts)
      result -> result
    end)
  end

  defp resolve(result, deadline, opts) do
    case poll(lookup(result), deadline, opts.poll) do
      {:done, status} -> Map.merge(result, %{outcome: status, late: true})
      _pending_or_absent -> Map.put(result, :outcome, "unresolved")
    end
  end

  defp recover(result, deadline, opts) do
    case send_request(result) do
      %{status: 202, body: %{"transfer_id" => transfer_id}} ->
        result
        |> Map.merge(%{transfer_id: transfer_id, recovered: true})
        |> resolve(deadline, opts)

      other ->
        Map.merge(result, Map.put(refused(other), :recovered, true))
    end
  rescue
    _still_failing -> result
  end

  defp lookup(%{op: :transfer, transfer_id: id}), do: fn -> transfer_outcome(id) end
  defp lookup(%{op: :deposit, transfer_id: id, to: to}), do: fn -> credit_outcome(to, id) end

  # The management API refreshes its counts every few seconds: two empty samples in a row,
  # that far apart, mean the queues really drained.
  defp wait_for_empty_queues(deadline, empty_samples \\ 0)

  defp wait_for_empty_queues(_deadline, 2), do: :ok

  defp wait_for_empty_queues(deadline, empty_samples) do
    if now() < deadline do
      waiting =
        queues()
        |> Enum.reject(fn {queue, _messages} -> String.ends_with?(queue, ".dead") end)
        |> Enum.map(fn {_queue, messages} -> messages end)
        |> Enum.sum()

      Process.sleep(5_000)
      wait_for_empty_queues(deadline, if(waiting == 0, do: empty_samples + 1, else: 0))
    end
  end

  defp check(initial, results, dead_letters_before, opts) do
    mismatches =
      initial
      |> Books.expected_balances(results)
      |> Task.async_stream(&mismatch(&1, opts), max_concurrency: 10, timeout: :infinity)
      |> Enum.flat_map(fn {:ok, mismatch} -> List.wrap(mismatch) end)

    %{status: 200, body: %{"balanced" => balanced}} = Ledger.trial_balance()
    dead_letters = dead_letters() - dead_letters_before
    unresolved = Enum.count(results, &(&1.outcome == "unresolved"))

    %{
      ok: mismatches == [] and balanced and dead_letters == 0 and unresolved == 0,
      mismatches: mismatches,
      balanced: balanced,
      dead_letters: dead_letters,
      unresolved: unresolved
    }
  end

  defp mismatch({account_id, expected}, opts) do
    eventually(fn -> Flows.assert_balance(account_id, expected) end, opts.drain_timeout * 1_000)
    nil
  rescue
    ExUnit.AssertionError ->
      %{
        account_id: account_id,
        expected: expected,
        accounts: Accounts.get_account(account_id).body["available_balance"],
        ledger: Ledger.balance(account_id).body["balance"]
      }
  end

  defp dead_letters do
    RabbitMQ.queues()
    |> Enum.filter(fn {queue, _messages} -> String.ends_with?(queue, ".dead") end)
    |> Enum.map(fn {_queue, messages} -> messages end)
    |> Enum.sum()
  end

  ## Report

  defp operation_report(results, operation, opts) do
    results = Enum.filter(results, &(&1.op == operation))
    settled = for %{settle_ms: ms} <- results, do: ms

    %{
      outcomes: Enum.frequencies_by(results, & &1.outcome),
      errors: client_errors(results),
      recovered: Enum.count(results, &Map.get(&1, :recovered, false)),
      accept: Stats.summary(for %{accept_ms: ms} <- results, do: ms),
      settle: Stats.summary(settled),
      settled_per_second: Float.round(length(settled) / opts.duration, 1)
    }
  end

  # Refusals carry a reason too, but they are answers, not errors.
  defp client_errors(results) do
    reasons = for %{reason: reason} = result <- results, result.outcome != "refused", do: reason
    Enum.frequencies(reasons)
  end

  defp config(opts), do: %{opts | weights: Map.new(opts.weights)}

  defp now, do: System.monotonic_time(:millisecond)
end
