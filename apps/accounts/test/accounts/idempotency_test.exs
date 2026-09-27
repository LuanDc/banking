defmodule Accounts.IdempotencyTest do
  use Accounts.DataCase, async: true

  alias Accounts.Idempotency

  setup do
    %{scope: Ecto.UUID.generate(), key: Ecto.UUID.generate()}
  end

  test "a new key names the transfer it was claimed for", %{scope: scope, key: key} do
    assert {:ok, "transfer-1"} = Idempotency.claim(scope, key, "transfer|400", "transfer-1")
  end

  test "a repeated key with the same request names the first transfer", %{scope: scope, key: key} do
    {:ok, "transfer-1"} = Idempotency.claim(scope, key, "transfer|400", "transfer-1")

    assert {:ok, "transfer-1"} = Idempotency.claim(scope, key, "transfer|400", "transfer-2")
  end

  test "a repeated key with another request is refused", %{scope: scope, key: key} do
    {:ok, "transfer-1"} = Idempotency.claim(scope, key, "transfer|400", "transfer-1")

    assert {:error, :idempotency_key_reused} =
             Idempotency.claim(scope, key, "transfer|500", "transfer-2")
  end

  test "a key is only unique within its scope", %{scope: scope, key: key} do
    {:ok, "transfer-1"} = Idempotency.claim(scope, key, "transfer|400", "transfer-1")

    assert {:ok, "transfer-2"} =
             Idempotency.claim(Ecto.UUID.generate(), key, "transfer|400", "transfer-2")
  end

  test "a key older than 24 hours starts a new transfer", %{scope: scope, key: key} do
    {:ok, "transfer-1"} = Idempotency.claim(scope, key, "transfer|400", "transfer-1")
    expire(scope, key)

    assert {:ok, "transfer-2"} = Idempotency.claim(scope, key, "transfer|500", "transfer-2")
  end

  defp expire(scope, key) do
    a_day_ago = DateTime.add(DateTime.utc_now(), -25, :hour)

    Repo.update_all(where(Accounts.IdempotencyKey, scope: ^scope, key: ^key),
      set: [inserted_at: a_day_ago]
    )
  end
end
