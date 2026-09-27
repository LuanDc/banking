defmodule E2E.Eventually do
  @moduledoc """
  Retries a block of assertions until it passes or time runs out.

  Reads come from read models, which follow the event store a moment later (docs, D11), and a
  saga crosses RabbitMQ twice. A story therefore states where the system must end up, not
  when: `eventually(fn -> assert ... end)`. On timeout the last failure is raised, so the
  message shows how far the system got.
  """

  @timeout 10_000
  @interval 100

  @spec eventually((-> result), pos_integer()) :: result when result: var
  def eventually(fun, timeout \\ @timeout) do
    retry(fun, System.monotonic_time(:millisecond) + timeout)
  end

  defp retry(fun, deadline) do
    fun.()
  rescue
    error in [ExUnit.AssertionError, MatchError] ->
      if System.monotonic_time(:millisecond) >= deadline do
        reraise error, __STACKTRACE__
      else
        Process.sleep(@interval)
        retry(fun, deadline)
      end
  end
end
