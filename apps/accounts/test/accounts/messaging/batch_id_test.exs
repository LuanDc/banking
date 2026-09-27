defmodule Accounts.Messaging.BatchIdTest do
  use ExUnit.Case, async: true

  alias Accounts.Messaging.BatchId

  describe "uuid5/2" do
    test "matches RFC 9562's example" do
      dns = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

      assert BatchId.uuid5(dns, "www.example.com") == "2ed6657d-e927-568b-95e1-2665a8aea6a2"
    end
  end

  describe "settlement/1" do
    test "is the same for the same transfer, so a redelivery lands on the same batch" do
      transfer_id = Ecto.UUID.generate()

      assert BatchId.settlement(transfer_id) == BatchId.settlement(transfer_id)
    end

    test "is an id of its own, different for each transfer" do
      [first, second] = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      assert BatchId.settlement(first) != first
      assert BatchId.settlement(first) != BatchId.settlement(second)
    end
  end
end
