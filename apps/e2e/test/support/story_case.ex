defmodule E2E.StoryCase do
  @moduledoc """
  Case template for a story: a scenario told through the public API only.

  Each story creates its own customers and keys, so stories run concurrently against the same
  running services and never depend on each other's data. The steps come from `E2E.Flows`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import E2E.Eventually
      import E2E.Flows

      alias E2E.Accounts
      alias E2E.Broker
      alias E2E.Ledger
    end
  end
end
