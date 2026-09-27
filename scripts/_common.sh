# shellcheck shell=bash
# Shared by scripts/e2e.sh and scripts/load.sh: sourced, never run on its own.
#
# The stories and the load generator run in the dev container's `workspace`, so the host needs
# only Docker. The services under test are the prod releases of the root docker-compose.yml.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

DEV_COMPOSE=(docker compose -f docker-compose.yml -f .devcontainer/compose.yaml)

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
fail() { printf '\033[31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

has_docker() { command -v docker >/dev/null 2>&1; }

# Inside the dev container there is no Docker CLI, but the services are one hop away.
inside_workspace() { ! has_docker && [ -n "${ACCOUNTS_URL:-}" ]; }

# Starts the workspace alone when it is not running. `--no-deps` leaves Postgres and RabbitMQ as
# they are, so the load limits on them survive; an attached VS Code keeps its container.
ensure_workspace() {
  if [ -z "$("${DEV_COMPOSE[@]}" ps --status running -q workspace)" ]; then
    step "Starting the workspace container (tests and load generator)"
    "${DEV_COMPOSE[@]}" up -d --no-deps workspace
  fi
}

# Runs a command in apps/e2e, in the workspace, with the e2e deps fetched.
in_e2e() {
  local command="cd apps/e2e && mix deps.get >/dev/null && $*"

  if inside_workspace; then
    bash -c "$command"
  else
    "${DEV_COMPOSE[@]}" exec -T workspace bash -c "$command"
  fi
}

# Waits until both services answer, as seen from where the stories run.
wait_for_services() {
  local accounts="${ACCOUNTS_URL:-http://accounts:4000}" ledger="${LEDGER_URL:-http://ledger:4001}"
  local check="curl -fs -o /dev/null $accounts/api/accounts?customer_id=probe \
    && curl -fs -o /dev/null $ledger/api/trial-balance"

  for _ in $(seq 1 60); do
    if inside_workspace; then
      bash -c "$check" && return 0
    else
      "${DEV_COMPOSE[@]}" exec -T workspace bash -c "$check" && return 0
    fi
    sleep 2
  done

  fail "The services did not answer at $accounts and $ledger."
}

# Quotes the arguments so they survive the trip through `bash -c`.
quoted() { printf ' %q' "$@"; }
