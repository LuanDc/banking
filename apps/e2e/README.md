# 🎬 e2e · Story tests and load tests across both services

Unit tests prove each rule, but they can't prove the whole story. Here the story is a deposit
crossing RabbitMQ twice, a saga compensating, and both books agreeing at the end. This suite
drives the **running** services from the outside, the way a client would, and checks where the
system ends up (D15).

The same steps also drive a **load test**: many customers at once, at a fixed rate, with the
same check at the end that both books agree (D16).

[← Back to the project](../../README.md) · [📐 Design doc](../../docs/event_storming.md#d15--story-tests-drive-the-running-services-from-outside)

| | |
| --- | --- |
| 🧰 Stack | ExUnit · [Req](https://github.com/wojtekmach/req) (HTTP) · [AMQP](https://github.com/pma/amqp) (replaying messages) |
| 🔌 Talks to | the Accounts and Ledger HTTP APIs and RabbitMQ. It shares no code with either service |
| ⏱️ Runtime | a few seconds; the stories run concurrently |
| 📈 Load test | `mix e2e.load`, on the same clients and steps: [Load test](#load-test) |

**Contents:** [How a story works](#how-a-story-works) · [Run it](#run-it) · [Stories](#stories) ·
[Replay them in Postman](#replay-them-in-postman) · [Writing a story](#writing-a-story) ·
[Load test](#load-test)

---

## How a story works

```mermaid
sequenceDiagram
    autonumber
    participant T as 🎬 Story (ExUnit)
    participant A as 🏦 accounts
    participant MQ as 🐇 RabbitMQ
    participant L as 📒 ledger

    T->>A: POST /api/transfers
    A-->>T: 202 pending
    A->>MQ: BookTransactionBatch
    MQ->>L: book
    L->>MQ: LedgerBatchBooked
    MQ->>A: confirm + post
    loop eventually (≤ 10s)
        T->>A: GET /api/transfers/{id}
        T->>L: GET /api/ledger-accounts/{id}/balance
    end
    Note over T: completed, and both books agree ✅
```

- ⏳ **`eventually/1`**: reads come from read models (D11), so a story says *where* the system
  must end up, not *when*. It retries the assertions for up to 10s and then raises the last
  failure.
- ⚖️ **`assert_balance/2`**: checks the same amount in both books, the available balance in
  Accounts and the ledger balance in the Ledger (D2).
- 🧍 **Isolation**: each story opens its own accounts with fresh keys, so stories run
  concurrently against a shared dev database.
- 🧷 **Sentinel**: both consumers handle one message at a time, in order (D10). To prove a replayed
  message was handled, a story sends a small deposit after it and waits for it to land.

## Run it

> 🐳 Needs the whole stack running: both services and RabbitMQ. The script starts nothing, so it
> runs the same on your machine, in the dev container or against another server.

**One command, from the repo root** (needs Elixir, curl, and Newman or npx):

```bash
scripts/e2e.sh                                  # check the services, then mix test, then Newman
scripts/e2e.sh test/stories/transfer_test.exs   # extra arguments go to mix test
scripts/e2e.sh --skip-newman

# 🌍 Against another server
ACCOUNTS_URL=http://staging:4000 LEDGER_URL=http://staging:4001 \
  RABBITMQ_URL=amqp://banking:banking@staging:5672 scripts/e2e.sh
```

| Step | What the script does |
| --- | --- |
| 🩺 Check | pings Accounts, the Ledger, its `pix-settlement` account, RabbitMQ (AMQP) and its management API. If one is down, it logs which and stops |
| 🎬 Stories | `mix deps.get`, then `mix test` in `apps/e2e` |
| 📮 Mirror | Newman on the Postman collection, with the same URLs |

| Variable | Default | Used for |
| --- | --- | --- |
| `ACCOUNTS_URL` | `http://localhost:4000` | the Accounts API |
| `LEDGER_URL` | `http://localhost:4001` | the Ledger API |
| `RABBITMQ_URL` | `amqp://banking:banking@localhost:5672` | the broker, where replayed messages go |
| `RABBITMQ_MANAGEMENT_URL` | `RABBITMQ_URL`'s user and host, port 15672 | queue counts and dead letters |

The defaults match `docker compose up -d --wait` on your machine. The dev container's workspace
already sets the variables to the other containers.

**By hand**, against a stack that is already up. In the dev container, `ACCOUNTS_URL`,
`LEDGER_URL` and `RABBITMQ_URL` already point at the services:

```bash
cd apps/e2e
mix test
```

On the host, with your own Elixir, the defaults point at the published ports. The services can
also run on the host instead of in Docker (see each service's
[run in dev](../accounts/README.md#run-in-dev)). The suite doesn't care where they run.

If a service is down, `test_helper.exs` stops right away and tells you what to start.
Point the suite elsewhere with `ACCOUNTS_URL`, `LEDGER_URL` and `RABBITMQ_URL`. The RabbitMQ
management API defaults to the broker's host on port 15672; `RABBITMQ_MANAGEMENT_URL` overrides it.

## Stories

| File | Story | Crosses |
| --- | --- | --- |
| [`account_lifecycle_test`](test/stories/account_lifecycle_test.exs) | 🆕 opening an account opens its ledger account | Accounts → 🐇 → Ledger |
| | 🔒 an account with money can't close until it is emptied | full saga + close + ledger close |
| | 🚫 a transition the FSM doesn't allow is refused | Accounts |
| [`deposit_test`](test/stories/deposit_test.exs) | 📥 an inbound PIX lands in both books | Accounts → 🐇 → Ledger → 🐇 → Accounts |
| | 🔁 a repeated `Idempotency-Key` credits once | same, plus a sentinel |
| | 🧊 a frozen account refuses a PIX | Accounts |
| [`transfer_test`](test/stories/transfer_test.exs) | 💸 a transfer moves money, in both books | full saga, batch entries |
| | 🟠 a blocked account still receives | credit matrix through the saga |
| | ↩️ a frozen destination: the saga gives the money back | compensation |
| | ❌ above the available balance: refused at once | Accounts |
| | 🟠 a blocked account cannot send | Accounts |
| | 🔁 a repeated `Idempotency-Key` starts no second transfer | full saga |
| | ✅ an invalid transfer never reaches an account | input rules (D14) |
| [`redelivery_test`](test/stories/redelivery_test.exs) | 📨 a redelivered `BookTransactionBatch` books nothing twice | replayed on `ledger.commands` |
| | 📨 a redelivered `LedgerBatchBooked` settles nothing twice | replayed on `ledger.events` |
| | 📨 a late `LedgerBatchRejected` for a booked batch gives nothing back | replayed on `ledger.events` |
| [`books_balance_test`](test/stories/books_balance_test.exs) | ⚖️ total debits equal total credits | Ledger trial balance |

## Replay them in Postman

Want to see it with your own eyes? [`postman/`](postman/) mirrors every story above, one folder
per test with the same requests and assertions, so you can double-check by hand.

| File | What it is |
| --- | --- |
| [⬇️ `banking.postman_collection.json`](postman/banking.postman_collection.json?raw=true) | the 17 stories, grouped by test file |
| [⬇️ `local.postman_environment.json`](postman/local.postman_environment.json?raw=true) | URLs and RabbitMQ credentials for the local stack, from the host |
| [⬇️ `devcontainer.postman_environment.json`](postman/devcontainer.postman_environment.json?raw=true) | the same, by service name, for Newman inside the dev container |

1. In Postman, **Import** both files and select the `local` environment.
2. Open a story folder and click **Run** (Collection Runner).
3. Watch each step: ids and keys chain from one request to the next, and the `Wait until …`
   steps repeat themselves until they pass, for up to 10 s.

The replay stories publish through the RabbitMQ management API (`:15672`), so they run in
Postman too. The `Wait until …` steps repeat only in the Runner. Sent one at a time, a step
that isn't ready yet just shows no result, so send it again.

From the terminal, the same collection runs with Newman:

```bash
npx newman run apps/e2e/postman/banking.postman_collection.json \
  -e apps/e2e/postman/local.postman_environment.json

# Inside the dev container (Newman is already installed there)
newman run apps/e2e/postman/banking.postman_collection.json \
  -e apps/e2e/postman/devcontainer.postman_environment.json
```

> 🧭 The ExUnit stories are the source of truth. The collection is a mirror: a change to a story
> updates its folder in the same commit, never the other way around.

## Writing a story

```elixir
defmodule E2E.Stories.MyStoryTest do
  use E2E.StoryCase, async: true

  test "what the customer sees happen" do
    from = funded_account(1_000)          # open + activate + PIX, waits until it lands
    to = active_account()
    key = new_key("transfer")             # the Idempotency-Key, for retries only

    assert %{status: 202, body: %{"transfer_id" => transfer_id}} =
             Accounts.transfer(from, to, 400, key)

    settled_transfer(transfer_id, "completed")    # eventually, through the saga
    eventually(fn -> assert_balance(from, 600) end)
  end
end
```

- Tell a story a customer or operator would recognize, across at least one boundary. An edge case
  of one rule belongs in the service's unit tests, where it costs a millisecond.
- Use only the public API and the RabbitMQ contract. Don't read the services' databases.
- Wrap every read that follows a command in `eventually`.
- Mirror it in [`postman/`](postman/) in the same commit: a folder with the test's name and the
  same steps. Then run both `mix test` and Newman.

## Load test

The stories prove that each flow ends in the right place. The load test asks whether it still
does with many customers at once, and how long it takes. It is written with the stories' own
parts: the same HTTP clients, the same steps (`E2E.Flows`), and the same final check that both
books agree.

```mermaid
flowchart LR
    S["🧰 Setup<br/>funded_account × N<br/>not measured"] --> L["📈 Load<br/>fixed rate, open model<br/>accept + settle times"]
    L --> D["⏳ Drain<br/>queues empty, late<br/>outcomes read back"]
    D --> C["⚖️ Check<br/>both books = expected<br/>trial balance · dead letters"]

    classDef step fill:#FFE082,stroke:#C8A300,color:#14202B
    class S,L,D,C step
```

### Run a load test

From the repo root, against services that are already up, wherever they run. The URLs come
from the same variables as the stories ([Run it](#run-it)):

```bash
scripts/load.sh
scripts/load.sh --rate 100 --duration 120 --accounts 50  # arguments go to mix e2e.load
scripts/load.sh --mix transfer=100

# 🌍 Against another server
ACCOUNTS_URL=http://staging:4000 LEDGER_URL=http://staging:4001 \
  RABBITMQ_URL=amqp://banking:banking@staging:5672 scripts/load.sh
```

1. 🩺 Pings every service, as `scripts/e2e.sh` does. If one is down, it logs which and stops.
2. 📊 Runs `mix e2e.load` and prints the report. The JSON report goes to
   `apps/e2e/load-results/` (ignored by git).

The script sets no limits. To measure the local stack in a small cloud footprint, start it with
[`docker-compose.load.yml`](../../docker-compose.load.yml) first:

```bash
# 📉 Base: ledger and accounts at 1 CPU · 512 MiB
docker compose -f docker-compose.yml -f docker-compose.load.yml up -d --build --wait ledger accounts

# 📈 Scaled: ledger and accounts at 2 CPUs · 768 MiB
BEAM_CPUS=2.0 BEAM_MEMORY=768m \
  docker compose -f docker-compose.yml -f docker-compose.load.yml up -d --build --wait ledger accounts

# ↩️ Take the limits off
docker compose up -d --wait
```

Postgres (2 CPUs, or `PG_CPUS` · 1 GiB) and RabbitMQ (1 CPU · 512 MiB) get their limits in both
scenarios. The
[root README](../../README.md#limit-resources-for-a-load-test) explains how they were picked.

The task also runs on its own: `cd apps/e2e && mix e2e.load`.

| Option | Default | Meaning |
| --- | --- | --- |
| `--rate` | 20 | operations started per second |
| `--duration` | 30 | seconds of load |
| `--accounts` | 20 | funded accounts in the pool; transfers go between random pairs |
| `--balance` | 1000000 | cents each pool account starts with, so transfers aren't refused |
| `--mix` | `transfer=80,deposit=15,read=5` | the weights of each operation |
| `--poll` | 100 | ms between two reads while waiting for an outcome |
| `--settle-timeout` | 30 | seconds an operation waits for its outcome during the load |
| `--drain-timeout` | 120 | seconds the check waits for late outcomes and balances |
| `--max-in-flight` | 2000 | operations at once; past it, a start is dropped and counted |
| `--pool-size` | 200 | HTTP connections per service |
| `--out` | · | also write the report as JSON |

### Watch it on the dashboards

Each service has a [LiveDashboard](../ledger/README.md#dashboard) that samples every second.
Open both before starting the load (`banking` / `banking`), on the **Metrics** tab:
http://localhost:4000/dashboard/metrics and http://localhost:4001/dashboard/metrics.
`scripts/load.sh` prints the links.

| If the report shows… | Look at | Bottleneck when |
| --- | --- | --- |
| 🐢 `settle` grows, `accept` stays low | **Accounts / Ledger** › `subscription.lag.events` | the lag keeps climbing: a projector, the saga or the outbox can't keep up |
| 🐇 a deep `Max backlog` | › `queue.messages` | a queue fills while its consumer is busy (one message at a time, D10) |
| ⚡ `accept` grows | › `repo.query.queue_time` | the wait for a connection grows faster than `query_time`: the pool is too small. Both grow: Postgres is |
| 🔥 everything slows down | **VM** › `scheduler_utilization.total` | near 100 %: the CPU quota is used up. Check the run queues too |
| 💥 failed or unresolved operations | › `error.count` | a `kind` appears: the exception says which part of the infrastructure failed |

The charts keep only what they gathered while the page was open. Postgres itself (locks,
long-running queries) is on the **Ecto Stats** tab.

### What it measures

- ⏱️ **Open model.** Operations start on the clock, whatever the answers. A slow system gets a
  growing queue, not a gentler load, as with real customers. `generator lag` shows how late the
  starts were: if it grows, the generator is the bottleneck.
- ⚡ **accept**: from the request to its answer (`202` for a transfer or a deposit).
- 🔁 **settle**: from the request until the outcome shows in the read model. A transfer crosses
  RabbitMQ twice, and each consumer takes one message at a time (D10), so a backlog shows here
  first while `accept` stays low.
- 🐇 **Max backlog**: the deepest each queue got, sampled every second from the management
  API, which refreshes its counts every few seconds.
- 🧮 The reads that wait for an outcome are part of the load, as they would be for any client.

### What it checks

At the end, the run fails unless every one of these holds:

| Check | How |
| --- | --- |
| ⚖️ Both books match the expected balance of every pool account | expected = initial + posted deposits ± completed transfers (`E2E.Load.Books`), then `assert_balance/2` in `eventually` |
| 📒 The trial balance holds | `GET /api/trial-balance` |
| 📭 No message was dead-lettered | the `*.dead` queues, before and after |
| ❓ Every outcome is known | what timed out is read again once the queues are empty |

A client-side error (a timeout, an exhausted pool) may still have reached the service. Once the
queues are empty, the request is sent again with the same `Idempotency-Key`, as a real client
would: the service answers with the transfer it already started, or starts it then (D17). The
report shows how many were `settled by a retry with the same key`. An exhausted client pool is the generator's limit,
not the services': raise `--pool-size` or `--poll`.

### Reading a report

```text
📈 Load: 200/s for 15s · 20 accounts · mix transfer=80 deposit=15 read=5
   sent 3000 · dropped 0 · took 26.6s · generator lag p99 3 ms

operation  count  outcomes                 accept ms          settle ms            settled/s
                                           p50 / p99 / max    p50 / p99 / max
transfer   2400   completed 2400           2894 / 5703 / 5843 11476 / 13303 / 13492 160.0
...
🐇 Max backlog: ledger.commands: 623 · accounts.ledger-events: 1 · ...

✅ Both books agree on all 20 accounts · trial balance balanced · dead letters: 0 · unresolved: 0
```

Here `ledger.commands` backs up and `settle` climbs to seconds while the Ledger works through
the queue: its single consumer (D10) is the ceiling. Compare the scaled limits: if throughput
doesn't follow the CPUs, the limit is elsewhere, likely Postgres, which both event stores write
to.

- 🔥 Every deposit debits the bank's single `pix-settlement` account (D13). Run
  `--mix deposit=100` to measure that hot spot on its own.
- 🧪 `test/load/` holds the unit tests of the pure parts, plus a one-second smoke run in the
  suite, so `mix test` keeps the runner working.
