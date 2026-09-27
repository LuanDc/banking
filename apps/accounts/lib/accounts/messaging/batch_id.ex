defmodule Accounts.Messaging.BatchId do
  @moduledoc """
  The id of the Ledger batch that settles a transfer (README, D17). A batch is an accounting
  entry with an id of its own, derived from the transfer's so a redelivered command lands on the
  same batch and books nothing twice (D4).
  """

  # Fixed for good: changing it would give every transfer a new settlement batch id.
  @namespace "b8b8964d-d15d-4a8c-99e9-b0cf16885f03"

  @doc "The id of the batch that settles `transfer_id`."
  def settlement(transfer_id), do: uuid5(@namespace, "settlement:" <> transfer_id)

  @doc "A name-based UUID, version 5 (RFC 9562): the same namespace and name, the same id."
  def uuid5(namespace, name) do
    digest =
      :sha
      |> :crypto.hash(Ecto.UUID.dump!(namespace) <> name)
      |> binary_part(0, 16)

    <<head::binary-size(6), _version::4, mid::bitstring-size(12), _variant::2, tail::bitstring>> =
      digest

    Ecto.UUID.cast!(<<head::binary, 5::4, mid::bitstring, 2::2, tail::bitstring>>)
  end
end
