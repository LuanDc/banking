defmodule Accounts.Middleware.ValidateCommand do
  @moduledoc """
  Checks every command against the input rules it declares (`Accounts.Command`, README D14)
  before it reaches its aggregate, whoever dispatches it: the API, the saga or the Ledger's
  events. An invalid command is answered with `{:error, {:validation_failed, fields}}` and never
  reaches the aggregate.
  """

  @behaviour Commanded.Middleware

  alias Accounts.Command
  alias Commanded.Middleware.Pipeline

  @impl Commanded.Middleware
  def before_dispatch(%Pipeline{command: command} = pipeline) do
    case Command.validate(command) do
      :ok ->
        pipeline

      {:error, _validation_failed} = error ->
        pipeline
        |> Pipeline.respond(error)
        |> Pipeline.halt()
    end
  end

  @impl Commanded.Middleware
  def after_dispatch(%Pipeline{} = pipeline), do: pipeline

  @impl Commanded.Middleware
  def after_failure(%Pipeline{} = pipeline), do: pipeline
end
