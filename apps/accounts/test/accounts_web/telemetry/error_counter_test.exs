defmodule AccountsWeb.Telemetry.ErrorCounterTest do
  use ExUnit.Case, async: true

  defmodule Boom do
    defexception message: "boom"

    require Logger

    def fail, do: Logger.error("failed")
    def warn, do: Logger.warning("slow")
  end

  setup do
    ref = make_ref()
    test = self()

    :telemetry.attach(
      ref,
      [:accounts, :error],
      fn _event, measurements, metadata, _config ->
        send(test, {:error_counted, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(ref) end)
  end

  test "counts an error log by the exception that crashed" do
    # The way a crashed process or request is reported.
    :logger.error("crashed", %{crash_reason: {%Boom{}, []}})

    assert_receive {:error_counted, %{count: 1},
                    %{kind: "AccountsWeb.Telemetry.ErrorCounterTest.Boom"}}
  end

  test "counts an error log without an exception by the module that logged it" do
    Boom.fail()

    assert_receive {:error_counted, %{count: 1},
                    %{kind: "AccountsWeb.Telemetry.ErrorCounterTest.Boom"}}
  end

  test "leaves warnings out" do
    Boom.warn()

    refute_receive {:error_counted, _, %{kind: "AccountsWeb.Telemetry.ErrorCounterTest.Boom"}}
  end
end
