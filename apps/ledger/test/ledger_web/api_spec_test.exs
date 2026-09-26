defmodule LedgerWeb.ApiSpecTest do
  # openapi.yaml is the source of truth (README, D12): the router serves exactly the operations it
  # documents, except the ones marked x-planned, which must not be routed yet.
  use ExUnit.Case, async: true

  alias LedgerWeb.ApiSpec

  test "the router and openapi.yaml have the same operations" do
    routed =
      for route <- Phoenix.Router.routes(LedgerWeb.Router),
          String.starts_with?(route.path, "/api"),
          into: MapSet.new(),
          do: {to_string(route.verb), ApiSpec.to_spec_path(route.path)}

    documented = MapSet.new(ApiSpec.operations())

    assert MapSet.difference(routed, documented) == MapSet.new(),
           "routed but not in openapi.yaml"

    assert MapSet.difference(documented, routed) == MapSet.new(),
           "in openapi.yaml but not routed (mark it x-planned: true if it is not built yet)"
  end
end
