import Config

# No force_ssl: the release serves plain HTTP inside the Docker stack (docker-compose.yml), which
# has no TLS. Behind a load balancer that terminates TLS, turn it on here (it is compile-time):
#
#     config :accounts, AccountsWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: true]

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
