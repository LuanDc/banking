defmodule Accounts.Command do
  @moduledoc """
  Declares a command: its fields, a constructor from request params, and the input rules it must
  meet before it is dispatched (README, D14).

      use Accounts.Command, fields: [:account_id, :reason]

      validates :account_id, presence: true
      validates :reason, presence: true

  The fields become the struct, `new/1` builds it from a map with string or atom keys
  (ExConstructor), and `validates/2` declares a Vex rule. Vex keeps one entry per field, so all of
  a field's rules go in a single `validates`.

  Input rules say what a command must carry: required fields, well-formed amounts, a destination
  that is another account. Business rules, which depend on the aggregate's state (the FSM, the
  available balance, the credit matrix), stay in the aggregate. `Accounts.Middleware.ValidateCommand`
  checks every command against its rules before it reaches the aggregate.
  """

  defmacro __using__(opts) do
    fields = Keyword.fetch!(opts, :fields)

    quote do
      defstruct unquote(fields)

      use ExConstructor
      use Vex.Struct
    end
  end

  @doc "`:ok`, or the messages for each field that breaks its rules."
  def validate(command) do
    case Vex.errors(command) do
      [] -> :ok
      errors -> {:error, {:validation_failed, to_fields(errors)}}
    end
  end

  @doc "README, D1: money is a positive integer number of cents."
  def positive_cents?(amount), do: is_integer(amount) and amount > 0

  @doc "The counterpart of a transfer is not the account itself."
  def other_account?(account_id, command), do: account_id != command.account_id

  defp to_fields(errors) do
    Enum.group_by(
      errors,
      fn {:error, field, _validator, _message} -> field end,
      fn {:error, _field, _validator, message} -> message end
    )
  end
end
