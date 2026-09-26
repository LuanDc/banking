import Config

# Force HTTPS (with HSTS). TLS is expected to be terminated at the
# load balancer, which must set the `x-forwarded-proto` header.
config :accounts, AccountsWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: true]

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
