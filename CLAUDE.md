# Banking lab

Two Phoenix services built on Commanded. `accounts/` is the Account Management Context and
`ledger/` is the Ledger Context. They share no code and no database. README.md is the design
document: sections 3–7 hold the model and section 10 the decisions (D1…D12). Read the relevant
decision before changing its area.

## Workflow

- Develop test-first, one red → green per behavior, following the `baby-steps-tdd` skill.
- Before every commit, run `mix test` and `mix quality` in each service you changed.
- Commit on `main` directly: there is no feature branch and no remote.
- Commit at each green step without asking first. Write the message with the
  `conventional-commits` skill.
- Once a list of steps is agreed, run them all in sequence. Stop only for design decisions that
  neither the README nor the conversation settles.

## Code rules

- **An aggregate's rules live in the aggregate module.** Keep guards, the FSM transition table
  and invariants there, not in helper modules such as `StateMachine`. Confirm before splitting
  a rule out, e.g. for `TransactionBatch`.
- **Each read-model table has a single owning projector** (D11). A projector reads only its own
  service's event store, never RabbitMQ.
- **The HTTP API's source of truth is the hand-written `<service>/openapi.yaml`** (D12).
  - Never generate the spec from code: no open_api_spex `operation` macros and no spec module in
    Elixir.
  - When an endpoint changes, update the YAML first, then the controller test, then the
    controller.
  - Every controller test validates its response against the YAML with
    `assert_response_schema(conn, status)` (`test/support/api_spec.ex`, JSV). The
    `api_spec_test.exs` test requires the router to serve exactly the spec's operations; an
    operation not built yet is marked `x-planned: true`.
  - Lint the spec with `npx @redocly/cli@1 lint <service>/openapi.yaml`.
  - Swagger UI: `docker compose up -d`, then http://localhost:8080.
- **Controllers call only the context entry point** (`Accounts.CustomerAccounts`,
  `Ledger.LedgerAccounts`, `Ledger.TransactionBatches`). It builds commands from the params with
  ExConstructor (`use ExConstructor` in the command, `Command.new(params)`), dispatches them, and
  holds the read-model queries.
- Break a pipe into one step per line, starting from the value on its own line (`params`, then
  `|> Command.new()`, then `|> App.dispatch()`), even when it would fit on one.
- Money is an integer number of cents (D1). Consumers deduplicate by `correlation_id` (D4).

## Local setup

`docker compose up -d` starts Postgres, RabbitMQ (management UI on :15672, user and password
`banking`) and Swagger UI (:8080). The services run on the host: accounts on :4000 and ledger on
:4001.
