defmodule E2E.Load.ReportTest do
  use ExUnit.Case, async: true

  alias E2E.Load.Report
  alias E2E.Load.Stats

  @report %{
    config: %{rate: 10, duration: 2, accounts: 4, weights: %{transfer: 3, read: 1}},
    sent: 20,
    dropped: 0,
    elapsed_ms: 2_010,
    generator_lag: Stats.summary([0, 1, 2]),
    operations: %{
      transfer: %{
        outcomes: %{"completed" => 14, "failed" => 1},
        errors: %{},
        recovered: 0,
        accept: Stats.summary([10, 12, 30]),
        settle: Stats.summary([80, 120, 400]),
        settled_per_second: 7.5
      },
      deposit: %{
        outcomes: %{},
        errors: %{},
        recovered: 0,
        accept: Stats.summary([]),
        settle: Stats.summary([]),
        settled_per_second: 0.0
      },
      read: %{
        outcomes: %{"ok" => 5},
        errors: %{},
        recovered: 0,
        accept: Stats.summary([3, 4]),
        settle: Stats.summary([]),
        settled_per_second: 0.0
      }
    },
    backlog: %{"ledger.commands" => 12, "accounts.ledger-events" => 3},
    consistency: %{ok: true, mismatches: [], balanced: true, dead_letters: 0, unresolved: 0}
  }

  test "shows each operation's outcomes and latencies, the backlog and the verdict" do
    text = Report.format(@report)

    assert text =~ "10/s for 2s"

    assert text =~
             ~r/transfer\s+15\s+completed 14 · failed 1\s+12 \/ 30 \/ 30\s+120 \/ 400 \/ 400/

    assert text =~ ~r/read\s+5\s+ok 5/
    refute text =~ "deposit"
    assert text =~ "ledger.commands: 12"
    assert text =~ "✅ Both books agree"
    refute text =~ "Errors"
  end

  test "lists why operations failed on the client side" do
    transfer = %{
      @report.operations.transfer
      | outcomes: %{"completed" => 14, "error" => 3},
        errors: %{"timeout" => 2, "HTTP 500" => 1},
        recovered: 1
    }

    text = Report.format(put_in(@report.operations.transfer, transfer))

    assert text =~ "⚠️ Errors"
    assert text =~ "transfer: timeout ×2 · HTTP 500 ×1 (1 settled by a retry with the same key)"
  end

  test "names each account whose books do not add up" do
    consistency = %{
      ok: false,
      mismatches: [%{account_id: "acc-1", expected: 900, accounts: 900, ledger: 1_000}],
      balanced: true,
      dead_letters: 2,
      unresolved: 0
    }

    text = Report.format(%{@report | consistency: consistency})

    assert text =~ "❌"
    assert text =~ "acc-1: expected 900, accounts 900, ledger 1000"
    assert text =~ "dead letters: 2"
  end
end
