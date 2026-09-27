defmodule E2E.Load.Workload do
  @moduledoc """
  What the load test sends, and when: the operation mix and the arrival schedule.
  """

  @type operation :: :transfer | :deposit | :read
  @type weights :: [{operation, pos_integer()}]

  @operations %{"transfer" => :transfer, "deposit" => :deposit, "read" => :read}

  @doc ~S'The mix from the command line, e.g. `"transfer=80,deposit=15,read=5"`.'
  @spec parse_weights(String.t()) :: {:ok, weights} | {:error, String.t()}
  def parse_weights(text) do
    text
    |> String.split(",", trim: true)
    |> Enum.reduce_while({:ok, []}, fn pair, {:ok, weights} ->
      case parse_pair(pair) do
        {:ok, weight} -> {:cont, {:ok, [weight | weights]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, weights} -> {:ok, Enum.reverse(weights)}
      error -> error
    end
  end

  defp parse_pair(pair) do
    with [name, weight] <- String.split(pair, "=", parts: 2),
         {:ok, operation} <- operation(name),
         {weight, ""} when weight > 0 <- Integer.parse(weight) do
      {:ok, {operation, weight}}
    else
      {:error, _message} = error -> error
      _not_a_weight -> {:error, "invalid weight: #{pair}"}
    end
  end

  defp operation(name) do
    case Map.fetch(@operations, name) do
      {:ok, operation} -> {:ok, operation}
      :error -> {:error, "unknown operation: #{name}"}
    end
  end

  @doc """
  When each operation starts, in ms from the beginning: `rate` per second for `duration`
  seconds, evenly spaced. It is an open model: starts follow the clock, not the answers, so a
  slow system gets a queue instead of a gentler load.
  """
  @spec arrivals(pos_integer(), pos_integer()) :: [non_neg_integer()]
  def arrivals(rate, duration) do
    for i <- 0..(rate * duration - 1), do: div(i * 1000, rate)
  end

  @doc """
  The next `count` operations, dealt in cycles: each cycle holds every operation as many times as
  its weight, shuffled. The mix is exact at every full cycle, and the order still varies.
  """
  @spec plan(weights, non_neg_integer()) :: [operation]
  def plan(weights, count) do
    deck = Enum.flat_map(weights, fn {operation, weight} -> List.duplicate(operation, weight) end)

    fn -> Enum.shuffle(deck) end
    |> Stream.repeatedly()
    |> Stream.concat()
    |> Enum.take(count)
  end
end
