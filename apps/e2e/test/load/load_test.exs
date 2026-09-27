defmodule E2E.LoadTest do
  # A smoke test of the load runner against the running services: a second of a light mix, then
  # the same consistency checks a real run ends with. `mix e2e.load` is the real run.
  use ExUnit.Case, async: true

  test "a short load run sends every planned operation and leaves both books matching" do
    report =
      E2E.Load.run(
        rate: 6,
        duration: 1,
        accounts: 3,
        weights: [transfer: 1, deposit: 1, read: 1]
      )

    assert report.sent == 6
    assert report.dropped == 0
    assert report.operations.transfer.accept.count == 2
    assert report.operations.deposit.settle.count == 2
    assert %{ok: true, mismatches: [], dead_letters: 0, balanced: true} = report.consistency
  end
end
