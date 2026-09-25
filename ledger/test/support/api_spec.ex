defmodule LedgerWeb.ApiSpec do
  @moduledoc """
  The hand-written `openapi.yaml`, the API's source of truth (README, D12), as test assertions.

  `assert_response_schema/2` finds the operation a request hit through the Phoenix route, and
  validates the response body against that operation's schema for the status, so a controller
  cannot drift from the spec.
  """

  import ExUnit.Assertions

  @spec_path Path.expand("../../openapi.yaml", __DIR__)
  @external_resource @spec_path

  @methods ~w(get post put patch delete)

  @doc "The decoded spec."
  def spec do
    cached({__MODULE__, :spec}, fn -> YamlElixir.read_from_file!(@spec_path) end)
  end

  @doc """
  The `{method, path}` of every operation in the spec, as `{"get", "/api/ledger-accounts/{account_id}"}`,
  leaving out the ones marked `x-planned: true`.
  """
  def operations do
    for {path, item} <- spec()["paths"],
        {method, operation} <- item,
        method in @methods,
        not Map.get(operation, "x-planned", false),
        do: {method, path}
  end

  @doc "Converts a Phoenix route, `/api/ledger-accounts/:account_id`, to its spec path."
  def to_spec_path(route), do: String.replace(route, ~r/:(\w+)/, "{\\1}")

  @doc """
  Asserts the response has `status`, that the spec documents that status for the operation, and
  that the body matches its schema. Returns the decoded body, or `nil` for a response with none.
  """
  def assert_response_schema(conn, status) do
    assert conn.status == status,
           "expected status #{status}, got #{conn.status}: #{conn.resp_body}"

    {method, path} = operation_of(conn)
    responses = get_in(spec(), ["paths", path, method, "responses"])

    assert responses,
           "#{String.upcase(method)} #{path} is not in openapi.yaml"

    assert Map.has_key?(responses, to_string(status)),
           "#{String.upcase(method)} #{path} does not document status #{status} in openapi.yaml"

    pointer = follow_ref(["paths", path, method, "responses", to_string(status)])

    case get_in(spec(), pointer ++ ["content", "application/json", "schema"]) do
      nil ->
        assert conn.resp_body == "", "status #{status} has no body in openapi.yaml"
        nil

      _schema ->
        body = Jason.decode!(conn.resp_body)
        validate!(body, pointer ++ ["content", "application/json", "schema"])
        body
    end
  end

  # A response may be a $ref to #/components/responses.
  defp follow_ref(pointer) do
    case get_in(spec(), pointer) do
      %{"$ref" => "#/" <> ref} ->
        ref |> String.split("/") |> Enum.map(&unescape/1) |> follow_ref()

      _response ->
        pointer
    end
  end

  defp operation_of(conn) do
    %{route: route} =
      Phoenix.Router.route_info(LedgerWeb.Router, conn.method, conn.request_path, conn.host)

    {String.downcase(conn.method), to_spec_path(route)}
  end

  defp validate!(body, pointer) do
    root = cached({__MODULE__, pointer}, fn -> build(pointer) end)

    case JSV.validate(body, root) do
      {:ok, _body} ->
        :ok

      {:error, error} ->
        flunk("""
        response does not match openapi.yaml at #{Enum.join(pointer, " > ")}:

        #{inspect(JSV.normalize_error(error), pretty: true)}

        body: #{inspect(body, pretty: true)}
        """)
    end
  end

  # The whole spec is the root, so the $refs to #/components resolve against it, and a $ref at
  # the top points at the schema under test.
  defp build(pointer) do
    ref = "#/" <> Enum.map_join(pointer, "/", &escape/1)

    spec()
    |> Map.put("$schema", "https://json-schema.org/draft/2020-12/schema")
    |> Map.put("$ref", ref)
    |> JSV.build!(formats: [__MODULE__.Int64 | JSV.default_format_validator_modules()])
  end

  defp escape(segment), do: segment |> String.replace("~", "~0") |> String.replace("/", "~1")
  defp unescape(segment), do: segment |> String.replace("~1", "/") |> String.replace("~0", "~")

  defp cached(key, fun) do
    case :persistent_term.get(key, nil) do
      nil -> tap(fun.(), &:persistent_term.put(key, &1))
      value -> value
    end
  end

  defmodule Int64 do
    @moduledoc false
    # OpenAPI's int64 format, which is not a JSON Schema one: every amount in cents (D1).
    @behaviour JSV.FormatValidator

    @impl true
    def supported_formats, do: ["int64"]

    @impl true
    def applies_to_type?("int64", data), do: is_integer(data)

    @impl true
    def validate_cast("int64", data) when data in -0x8000000000000000..0x7FFFFFFFFFFFFFFF,
      do: {:ok, data}

    def validate_cast("int64", _data), do: {:error, :out_of_range}
  end
end
