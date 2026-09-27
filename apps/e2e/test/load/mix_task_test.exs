defmodule Mix.Tasks.E2e.LoadTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.E2e.Load

  test "turns the command line into load options, the report path and the pool size" do
    argv =
      ~w(--rate 50 --duration 60 --accounts 30 --mix transfer=9,read=1 --out r.json --pool-size 300)

    assert Load.parse_args(argv) ==
             {:ok, [rate: 50, duration: 60, accounts: 30, weights: [transfer: 9, read: 1]],
              %{out: "r.json", pool_size: 300}}
  end

  test "refuses an unknown switch or a bad mix" do
    assert {:error, "unknown option: --rat"} = Load.parse_args(~w(--rat 5))
    assert {:error, "unknown operation: withdraw"} = Load.parse_args(~w(--mix withdraw=1))
  end
end
