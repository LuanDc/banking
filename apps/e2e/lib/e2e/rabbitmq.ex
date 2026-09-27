defmodule E2E.RabbitMQ do
  @moduledoc """
  Reads the broker's queues through the RabbitMQ management API (`:15672`).

  The load test samples the backlog while it runs and checks that no message was dead-lettered.
  The management API refreshes its counts every few seconds, so a sample shows a recent state,
  not this instant's.
  """

  @doc "Every queue on the default virtual host, with the messages waiting in it."
  @spec queues() :: %{String.t() => non_neg_integer()}
  def queues do
    %{status: 200, body: queues} = Req.get!(client(), url: "/api/queues/%2F")
    Map.new(queues, &{&1["name"], &1["messages"] || 0})
  end

  defp client do
    uri = URI.parse(Application.fetch_env!(:e2e, :rabbitmq_management_url))

    Req.new(
      base_url: URI.to_string(%{uri | userinfo: nil}),
      auth: {:basic, uri.userinfo},
      retry: false
    )
  end
end
