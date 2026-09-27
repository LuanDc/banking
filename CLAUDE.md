# Banking lab

Two Phoenix services built on Commanded, under `apps/`. `apps/accounts/` is the Account
Management Context and `apps/ledger/` is the Ledger Context. They share no code and no database;
run `mix` inside each one. `docs/event_storming.md` is the design document: sections 3–7 hold the
model and section 10 the decisions (D1…D17). Read the relevant decision before changing its
area. Code comments cite it as "README, Dn" from before it moved.

## Documentation

All docs are in English, written for developers who find the repo on GitHub.

- `README.md` (root) is only a navigator. It links to `docs/event_storming.md` and to each
  service's README sections, and holds no service detail.
- `apps/<service>/README.md` describes how that service works: tech stack, run in dev, HTTP API
  (Swagger download), aggregates, commands, events, database tables and queues. Update it in
  the same commit that changes any of those.
- Keep the text light and visual: tables, Mermaid diagrams, emoji markers. Keep emojis out of
  headings, so the anchors the root README links to stay stable.

## Workflow

- Develop test-first, one red → green per behavior, following the `baby-steps-tdd` skill.
- Before every commit, run `mix test` and `mix quality` in each service you changed.
- `apps/e2e` holds the story tests across both running services (D15). Before committing a
  change to a message, a saga step or an endpoint, start the prod stack
  (`docker compose up -d --build --wait`) and run `scripts/e2e.sh`. Add a story when a new flow
  crosses a boundary. Edge cases stay in the services' unit tests.
- `scripts/e2e.sh` and `scripts/load.sh` start nothing. They ping the services at
  `ACCOUNTS_URL`, `LEDGER_URL` and `RABBITMQ_URL` (localhost by default) and stop if one is
  down, then run `mix test` and Newman, or `mix e2e.load`, where they are called. That can be
  the host, the workspace or another server.
- The load test (`mix e2e.load`, D16) is told with the stories' steps (`E2E.Flows`). A change to
  a step serves both. To load-test under the limits, start the stack with
  `docker-compose.load.yml` before `scripts/load.sh`.
- Each service's `/dashboard` (LiveDashboard, `banking`/`banking`) charts what a load test pushes
  on: the pool's `queue_time`, the subscriptions' lag, the queues, the errors and the schedulers
  (`<App>Web.Telemetry`, its `Sampler` and `ErrorCounter`). A new bottleneck worth watching gets
  a metric there, in both services.
- **The Postman collection mirrors the e2e stories** (`apps/e2e/postman/`: the collection plus
  a `local` environment).
  - The ExUnit stories are the source of truth. The collection is there for anyone who wants to
    replay them by hand as a double check.
  - One folder per story, with the test's name, making the same requests and the same
    assertions in the same order.
  - Every change to a story (add, remove, rename, a new step or assertion) updates its folder
    in the same commit. Never change the collection alone: change the story first, then mirror
    it.
  - The folders use the same mechanisms as the stories:
    - chained variables for ids and fresh keys;
    - a request repeated with `pm.execution.setNextRequest` until it passes, capped, in place
      of `eventually`;
    - the RabbitMQ management API (`POST :15672/api/exchanges/%2F/<exchange>/publish`) for
      replayed messages.
  - Before committing, run both against the running stack: `mix test` in `apps/e2e`, then
    `npx newman run apps/e2e/postman/banking.postman_collection.json -e apps/e2e/postman/local.postman_environment.json`.
- Commit on `main` directly: there is no feature branch and no remote.
- Commit at each green step without asking first. Write the message with the
  `conventional-commits` skill.
- Once a list of steps is agreed, run them all in sequence. Stop only for design decisions that
  neither the README nor the conversation settles.

## Code rules

- **Aggregates live in `lib/<app>/aggregates/`**, named `<App>.Aggregates.<Name>`.
- **An aggregate's rules live in the aggregate module.** Keep guards, the FSM transition table
  and invariants there, not in helper modules such as `StateMachine`. Confirm before splitting
  a rule out, e.g. for `TransactionBatch`.
- **Each read-model table has a single owning projector** (D11). A projector reads only its own
  service's event store, never RabbitMQ.
- **The HTTP API's source of truth is the hand-written `apps/<service>/priv/openapi.yaml`** (D12).
  - Never generate the spec from code: no open_api_spex `operation` macros and no spec module in
    Elixir.
  - When an endpoint changes, update the YAML first, then the controller test, then the
    controller.
  - Every controller test validates its response against the YAML with
    `assert_response_schema(conn, status)` (`test/support/api_spec.ex`, JSV). The
    `api_spec_test.exs` test requires the router to serve exactly the spec's operations; an
    operation not built yet is marked `x-planned: true`.
  - Lint the spec with `npx @redocly/cli@1 lint apps/<service>/priv/openapi.yaml`.
  - Swagger UI: `docker compose up -d`, then http://localhost:8080.
- **Commands declare their input rules** with `use Accounts.Command, fields: [...]` plus Vex
  `validates` (one `validates` per field). The `ValidateCommand` middleware checks them before
  dispatch. Business rules that need the aggregate's state stay in the aggregate (D14).
- **Controllers call only the context entry point** (`Accounts.CustomerAccounts`,
  `Ledger.LedgerAccounts`, `Ledger.TransactionBatches`). It builds commands from the params with
  ExConstructor (`Command.new(params)`, from `use Accounts.Command`), dispatches them, and
  holds the read-model queries.
- Break a pipe into one step per line, starting from the value on its own line (`params`, then
  `|> Command.new()`, then `|> App.dispatch()`), even when it would fit on one.
- Money is an integer number of cents (D1). Consumers deduplicate by `correlation_id` (D4).

## Local setup

Only Docker is required. Postgres, RabbitMQ (management UI on :15672, user and password
`banking`), Swagger UI (:8080) and both services (ledger on :4001, then accounts on :4000) run in
one of two modes. Both share the project name, so starting one recreates the services in it.

- **Dev**: the dev container (VS Code's **Reopen in Container**, or
  `docker compose -f docker-compose.yml -f .devcontainer/compose.yaml up -d --wait`).
  `.devcontainer/compose.yaml` turns the services into `mix phx.server` from the mounted source
  with the dev image (`.devcontainer/Dockerfile`). Each runs `mix setup` on start, on the
  `*_dev` databases. It adds the `workspace` container
  (`docker compose -f docker-compose.yml -f .devcontainer/compose.yaml exec workspace bash`) for
  `mix test`, `mix quality`, the e2e stories and Newman. Each app's `deps` and `_build` live in
  named volumes, never in the host's directories. Inside the workspace, use the `devcontainer`
  Postman environment instead of `local`.
- **Prod**: the root `docker-compose.yml` alone, `docker compose up -d --build --wait`, for the
  e2e stories and load tests. Each service's image is a `mix release` built by
  `apps/<service>/Dockerfile`; `--build` picks up code changes. The workspace keeps running.
  - `bin/setup` (`<App>.Release.setup/0`, the release's `mix setup`) runs on every start and
    creates the `*_prod` databases. A new setup step goes in both the `mix setup` alias and the
    `Release` module.
  - `config/prod.exs` has no `force_ssl`: the stack serves plain HTTP.
- The dev and test configs read `PGHOST`, `RABBITMQ_URL` and (dev) `PHX_IP`; the defaults are
  the host's `localhost`, so running a service on the host still works: start only
  `postgres rabbitmq swagger-ui`, and stop the Docker service on the same port first.

The Ledger's seeds (`mix run priv/repo/seeds.exs`, part of `mix setup`) open the bank's
`pix-settlement` account. Deposits need it, since an inbound PIX debits it (D13).
