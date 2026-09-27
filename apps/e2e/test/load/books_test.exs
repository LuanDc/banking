defmodule E2E.Load.BooksTest do
  use ExUnit.Case, async: true

  alias E2E.Load.Books

  test "a completed transfer moves its amount, a posted deposit adds it" do
    initial = %{"a" => 1_000, "b" => 1_000}

    results = [
      %{op: :transfer, outcome: "completed", from: "a", to: "b", amount: 300},
      %{op: :deposit, outcome: "posted", to: "a", amount: 50}
    ]

    assert Books.expected_balances(initial, results) == %{"a" => 750, "b" => 1_300}
  end

  test "failed, refused and read operations move nothing" do
    initial = %{"a" => 1_000, "b" => 1_000}

    results = [
      %{op: :transfer, outcome: "failed", from: "a", to: "b", amount: 300},
      %{op: :transfer, outcome: "refused", from: "a", to: "b", amount: 300},
      %{op: :deposit, outcome: "rejected", to: "a", amount: 50},
      %{op: :read, outcome: "ok"}
    ]

    assert Books.expected_balances(initial, results) == initial
  end
end
