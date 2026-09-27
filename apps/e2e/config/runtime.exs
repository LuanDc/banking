import Config

# Where the running services and the broker are. The defaults match docker-compose.yml and each
# service's dev config.
rabbitmq_url = System.get_env("RABBITMQ_URL", "amqp://banking:banking@localhost:5672")

# The management API, where the load test samples the queues and counts dead letters: by default
# the broker's own host and user, on the management port.
management_url =
  rabbitmq_url
  |> URI.parse()
  |> Map.merge(%{scheme: "http", port: 15672, path: nil})
  |> URI.to_string()

config :e2e,
  accounts_url: System.get_env("ACCOUNTS_URL", "http://localhost:4000"),
  ledger_url: System.get_env("LEDGER_URL", "http://localhost:4001"),
  rabbitmq_url: rabbitmq_url,
  rabbitmq_management_url: System.get_env("RABBITMQ_MANAGEMENT_URL", management_url)
