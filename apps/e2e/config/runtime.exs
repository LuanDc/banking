import Config

# Where the running services and the broker are. The defaults match docker-compose.yml and each
# service's dev config.
config :e2e,
  accounts_url: System.get_env("ACCOUNTS_URL", "http://localhost:4000"),
  ledger_url: System.get_env("LEDGER_URL", "http://localhost:4001"),
  rabbitmq_url: System.get_env("RABBITMQ_URL", "amqp://banking:banking@localhost:5672")
