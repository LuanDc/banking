---
name: baby-steps-tdd
description: How to develop in this repository - strict TDD in baby steps, plus the policy of which tests go in which layer so the suite stays cheap to run. Use this whenever you are about to write or change Elixir code here: a new aggregate, command, event, projection, context function, controller or plug, a bug fix, a refactor, or a "quick" change that looks too small to test. Also use it when deciding where a test belongs, when a test needs the database, the event store or the Phoenix endpoint, or when the suite starts feeling slow.
---

# Baby steps + TDD

Two rules carry everything else: **no production code without a failing test that demands it**, and
**each step is small enough that you can undo it without regret**. Everything below serves those.

## The loop

Every change goes through red → green → refactor, in this order:

1. **Red.** Write one test for one behavior. Run it. Watch it fail, and read the failure: it must
   fail for the reason you expect. A test that passes before the code exists is testing nothing,
   and a test that fails with `UndefinedFunctionError` when you expected a wrong amount is telling
   you it is not wired the way you think.
2. **Green.** Write the least code that makes it pass — including returning a hardcoded value if
   that is genuinely all the test demands. The next test is what forces the generalization. Run the
   test.
3. **Refactor.** Only with the bar green. Remove duplication, name things, extract functions. Run
   the tests again after each move.

Run the single test while you work, and the file's suite before moving on:

```sh
mix test test/ledger/accounts/account_test.exs:42   # the one test
mix test test/ledger/accounts/account_test.exs      # the file
mix test                                            # before committing
```

## How small is a baby step

A step is one behavior, and its diff is usually a handful of lines. Practical signals that a step
got too big:

- You cannot get back to green within a few minutes.
- You are editing a second module to satisfy the current test.
- You are debugging rather than implementing — with a small step, the cause is in what you just
  wrote, which is why the size matters.

When that happens, **revert to the last green** (`git stash` or undo the edit) and split the step.
Reverting a few lines costs seconds; untangling a half-finished refactor costs an afternoon. This
is the whole point of working small — the undo is always cheap.

Commit at green, once the behavior is complete and the suite passes. Follow the repository's
[conventional-commits](../conventional-commits/SKILL.md) skill for the
message.

## Where each test belongs

The suite is run dozens of times a day, so the cost of a test is a real cost. A test earns its
place at the **cheapest layer that can prove the behavior** — and at that layer only.

| Layer | Setup | What belongs here |
| --- | --- | --- |
| **Pure unit** — plain `ExUnit.Case, async: true` | none: no database, no app boot | Aggregates (`execute/2`, `apply/2` as pure functions), value objects, changesets, calculations, policy decisions. **Every edge case lives here**: boundaries, rounding, invalid input, each rejection reason, each state of an FSM. |
| **Data layer** — `Ledger.DataCase` | Postgres + Ecto sandbox | Only what genuinely needs the database: queries, unique and check constraints, migrations, projection writes. One test per behavior, not per variation. |
| **Integration / Phoenix** — `Ledger.ConnCase`, event store, Commanded end-to-end | endpoint, router, plugs, serialization, a real event store with no sandbox | **Smoke tests only.** One happy path per route or per wiring: the pieces are connected, the request reaches the context, the response has the right status and shape. |
| **Story** — `apps/e2e`, `E2E.StoryCase` | both services running, Postgres, RabbitMQ | **One story per flow that crosses a boundary**: a deposit, a transfer, a compensation, a redelivered message. It asserts where the system ends up, in both books, through `eventually`. It lives outside the services and runs before a commit that touches a message, a saga step or an endpoint (D15). |

The reasoning is about what each layer can prove. A pure test proves a rule; a controller test proves
plumbing. Asserting a rule through the controller pays the full cost of the stack to learn something
a millisecond-long test already told you — and when it breaks, it does not tell you where.

**One behavior, one layer.** Before adding an assertion to a DataCase or ConnCase test, ask whether a
pure test could make the same claim. If it could, that is where it goes.

### The pull to test edge cases from the outside

It happens when the rule is unreachable from a pure function — buried in a controller action, or in a
context function that starts by hitting the database. The fix is not a heavier test: it is to move the
decision into a module that takes data and returns data. Testability pressure is design feedback, and
following it is what keeps the expensive layers thin.

In this codebase the natural home for rules is the aggregate. A Commanded aggregate is a pure
function of state and command, so invariants — "debits equal credits", "a blocked account rejects a
debit" — are unit tests with no event store, no Postgres, no supervision tree.

### Keeping the expensive tests honest

- Tag them (`@moduletag :integration`) so they can be excluded during a tight red-green loop:
  `mix test --exclude integration`. The full suite still runs before a commit.
- Event store tests have no Ecto sandbox: the database is shared and state leaks between tests.
  Keep them few, make them `async: false`, and have each one use its own stream id.
- A smoke test asserts status and shape. If you catch yourself writing a third assertion about
  business rules in a ConnCase test, the rule belongs one layer down.

## Working checklist

- [ ] The test was written before the code, and failed for the expected reason.
- [ ] The production code is the smallest that makes it pass.
- [ ] The behavior is tested at the cheapest layer that can prove it, and only there.
- [ ] Edge cases are unit tests; DataCase and ConnCase tests stay at one happy path.
- [ ] Refactoring happened on green, with the tests run again afterwards.
- [ ] `mix test` passes; `mix quality` passes before the commit.

## Anti-patterns

- Writing a module and then the tests that describe it. The tests end up shaped like the code, and
  they no longer press on the design.
- One giant test per feature. It fails as a block, and it tells you little about which rule broke.
- Reproducing a bug by hand instead of writing the failing test first. The test is the proof the
  fix works, and the guard against the bug coming back.
- Copying an edge case into the ConnCase test "for safety". It doubles the cost and proves nothing new.
- Batching several behaviors into one big green step because it "was all related".
