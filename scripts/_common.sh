# shellcheck shell=bash
# Shared by scripts/e2e.sh and scripts/load.sh: sourced, never run on its own.
#
# The scripts start nothing: they run apps/e2e where they are called (the host, the dev
# container's workspace or another server) against services that are already up. Where those
# are comes from the same variables as apps/e2e/config/config.exs, with the same defaults.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

ACCOUNTS_URL="${ACCOUNTS_URL:-http://localhost:4000}"
LEDGER_URL="${LEDGER_URL:-http://localhost:4001}"
RABBITMQ_URL="${RABBITMQ_URL:-amqp://banking:banking@localhost:5672}"
export ACCOUNTS_URL LEDGER_URL RABBITMQ_URL

# Splits scheme://userinfo@host:port/... into URL_USERINFO, URL_HOST and URL_PORT.
split_url() {
  local authority="${1#*://}"
  authority="${authority%%/*}"
  URL_USERINFO=""
  case "$authority" in *@*) URL_USERINFO="${authority%@*}" ;; esac
  authority="${authority##*@}"
  URL_HOST="${authority%%:*}"
  URL_PORT="$2"
  case "$authority" in *:*) URL_PORT="${authority##*:}" ;; esac
}

split_url "$RABBITMQ_URL" 5672
RABBITMQ_HOST="$URL_HOST" RABBITMQ_PORT="$URL_PORT"

# The management API, as config.exs builds it: the broker's user and host, on port 15672.
RABBITMQ_MANAGEMENT_URL="${RABBITMQ_MANAGEMENT_URL:-http://${URL_USERINFO:+$URL_USERINFO@}$URL_HOST:15672}"
# Newman takes it without the credentials, and them apart.
split_url "$RABBITMQ_MANAGEMENT_URL" 15672
RABBITMQ_MANAGEMENT_BASE="${RABBITMQ_MANAGEMENT_URL%%://*}://$URL_HOST:$URL_PORT"
RABBITMQ_USER="${URL_USERINFO%%:*}"
RABBITMQ_PASSWORD="${URL_USERINFO#*:}"

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
ok() { printf '   \033[32m✔\033[0m %s\n' "$*"; }
fail() { printf '\033[31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is not installed here: $2"; }

# One HTTP GET that must answer 200; prints what came back otherwise.
ping_http() {
  local name="$1" url="$2" status
  shift 2
  status="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 10 "$@" "$url")" ||
    true
  if [ "$status" = 200 ]; then
    ok "$name · $url"
  else
    printf '   \033[31m✖\033[0m %s · %s (HTTP %s)\n' "$name" "$url" "${status:-000}" >&2
    return 1
  fi
}

# A TCP connection to the AMQP port: the stories publish and consume there.
ping_tcp() {
  local name="$1" host="$2" port="$3"
  if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
    ok "$name · $host:$port"
  else
    printf '   \033[31m✖\033[0m %s · %s:%s (no TCP connection)\n' "$name" "$host" "$port" >&2
    return 1
  fi
}

# Pings every service the stories and the load test drive, and stops when one is down.
check_services() {
  local down=0

  step "Checking the services"
  need curl "the connection check uses it."
  ping_http "Accounts" "$ACCOUNTS_URL/api/accounts?customer_id=probe" || down=1
  ping_http "Ledger" "$LEDGER_URL/api/trial-balance" || down=1
  ping_http "PIX settlement account" "$LEDGER_URL/api/ledger-accounts/pix-settlement" || down=1
  ping_tcp "RabbitMQ" "$RABBITMQ_HOST" "$RABBITMQ_PORT" || down=1
  ping_http "RabbitMQ management" "$RABBITMQ_MANAGEMENT_BASE/api/overview" \
    -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" || down=1

  [ "$down" = 0 ] ||
    fail "A service is down: start it, or point ACCOUNTS_URL, LEDGER_URL, RABBITMQ_URL (and RABBITMQ_MANAGEMENT_URL) at where it runs."
}

# Runs a command in apps/e2e with its deps fetched.
in_e2e() {
  need mix "apps/e2e runs with Elixir; install it, or run the script in the dev container's workspace."
  (cd apps/e2e && mix deps.get >/dev/null && "$@")
}
