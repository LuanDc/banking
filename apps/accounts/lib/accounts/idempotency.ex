defmodule Accounts.Idempotency do
  @moduledoc """
  The API's answer to a client's retry (README, D17): the same `Idempotency-Key` in the same
  scope names the same transfer. The key never reaches the domain: the aggregate decides each
  `transfer_id` once, and this table only tells a retry which `transfer_id` it is about.
  """

  import Ecto.Query

  alias Accounts.IdempotencyKey
  alias Accounts.Repo

  # A key guards against a client's retries, which come within minutes (README, D17).
  @window_hours 24

  @doc """
  Claims `key` in `scope` for `transfer_id`, or returns the transfer it already names.
  `fingerprint` describes the request: the same key with another request is refused.
  """
  def claim(scope, key, fingerprint, transfer_id) do
    now = DateTime.utc_now()
    expired = DateTime.add(now, -@window_hours, :hour)

    row = %IdempotencyKey{
      scope: scope,
      key: key,
      transfer_id: transfer_id,
      fingerprint: fingerprint,
      inserted_at: now
    }

    # The primary key makes the claim atomic: of two requests with the same key, one inserts
    # and the other finds its row. A row past the window is taken over, as a new key.
    take_over_expired =
      from(k in IdempotencyKey,
        where: k.inserted_at < ^expired,
        update: [set: [transfer_id: ^transfer_id, fingerprint: ^fingerprint, inserted_at: ^now]]
      )

    Repo.insert!(row,
      on_conflict: take_over_expired,
      conflict_target: [:scope, :key],
      allow_stale: true
    )

    case Repo.one!(where(IdempotencyKey, scope: ^scope, key: ^key)) do
      %IdempotencyKey{fingerprint: ^fingerprint, transfer_id: claimed} -> {:ok, claimed}
      %IdempotencyKey{} -> {:error, :idempotency_key_reused}
    end
  end
end
