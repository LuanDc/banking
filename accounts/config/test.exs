import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :accounts, Accounts.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "accounts_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# The event store has no Ecto sandbox, so tests share one database per
# partition and reset it between runs.
config :accounts, Accounts.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "accounts_eventstore_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :accounts, AccountsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "9YylYBTn6CnewILQJmYP0WD6A/83HmN0po5A6q3J/Q9ZLbe9IAY/7pIIHRMhQEqD",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Messages to other services go through a Mox mock of the publisher port.
config :accounts, Accounts.Messaging.Publisher, adapter: Accounts.Messaging.PublisherMock
