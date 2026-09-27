defmodule Ledger.LineageTest do
  use ExUnit.Case, async: true

  require Logger

  alias Ledger.Lineage

  @correlation_id "5b9a3c2e-8f1d-4e7a-9c3b-2d1e0f4a6b8c"
  @event_id "c0ffee00-1234-4abc-8def-0123456789ab"

  describe "from_event/1" do
    test "a command caused by an event joins its conversation" do
      metadata = %{correlation_id: @correlation_id, event_id: @event_id}

      assert Lineage.from_event(metadata) == [
               correlation_id: @correlation_id,
               causation_id: @event_id
             ]
    end
  end

  describe "from_message/1" do
    test "a command caused by a message joins its conversation, caused by the message" do
      metadata = %{correlation_id: @correlation_id, message_id: @event_id}

      assert Lineage.from_message(metadata) == [
               correlation_id: @correlation_id,
               causation_id: @event_id
             ]
    end

    test "leaves out what is missing or not a UUID, which the event store could not keep" do
      metadata = %{correlation_id: :undefined, message_id: "not-a-uuid"}

      assert Lineage.from_message(metadata) == []
    end
  end

  describe "log/1" do
    test "tags this process's logs with the conversation" do
      Lineage.log(correlation_id: @correlation_id, causation_id: @event_id)

      assert Logger.metadata()[:correlation_id] == @correlation_id
    end
  end
end
