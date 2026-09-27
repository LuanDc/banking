import Config

# The defaults match docker-compose.yml's published ports on the host; inside the Docker stack
# (docker-compose.yml, .devcontainer/) PGHOST and RABBITMQ_URL point at the service names.
pg_host = System.get_env("PGHOST", "localhost")
rabbitmq_url = System.get_env("RABBITMQ_URL", "amqp://banking:banking@localhost:5672")

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ledger, Ledger.Repo,
  username: "postgres",
  password: "postgres",
  hostname: pg_host,
  database: "ledger_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# The event store has no Ecto sandbox, so tests share one database per
# partition and reset it between runs.
config :ledger, Ledger.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "postgres",
  password: "postgres",
  hostname: pg_host,
  database: "ledger_eventstore_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 2

# The commands pipeline runs without a broker: tests feed it with Broadway.test_message/3.
config :ledger, Ledger.Messaging.CommandsConsumer, producer: {Broadway.DummyProducer, []}

# Projectors are called directly in tests: the event store has no sandbox.
config :ledger, start_projections: false

# RabbitMQ from docker-compose.yml, used only by the publisher's integration tests. The event
# publisher does not start in test, so no event handler publishes on its own; the handler's
# tests go through a Mox mock of the publisher port.
config :ledger, Ledger.Messaging.RabbitMQPublisher, url: rabbitmq_url
config :ledger, Ledger.Messaging.Publisher, adapter: Ledger.Messaging.PublisherMock
config :ledger, start_messaging: false

# The dashboard's credentials (LedgerWeb.DashboardAuth). The sampler behind its load-test charts
# does not start in test: its tests start their own.
config :ledger, :dashboard, username: "banking", password: "banking"
config :ledger, start_sampler: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ledger, LedgerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "OEPdKtWaTv0dNl/+8XJQn3RU81av794zzYrjCKMyVnBcHQVXUR+27Xa7Dti0pw9L",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
