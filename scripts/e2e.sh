#!/usr/bin/env bash
# Runs the story tests (apps/e2e) and their Postman mirror against the running services.
#
#   scripts/e2e.sh                          # prod stack, then `mix test`, then Newman
#   scripts/e2e.sh test/stories/transfer_test.exs
#   scripts/e2e.sh --dev                    # against the dev-mode services instead
#   scripts/e2e.sh --skip-newman
#
# From the host it starts the stack first: the prod releases, rebuilt from the current code
# (`docker compose up -d --build --wait`), which also drops any load limits. Inside the dev
# container, where there is no Docker, it runs against whatever mode is up.
# Other arguments go to `mix test`.

set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "$0")/_common.sh"

mode=prod
newman=true
mix_args=()

for arg in "$@"; do
  case "$arg" in
    --dev) mode=dev ;;
    --skip-newman) newman=false ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    *) mix_args+=("$arg") ;;
  esac
done

if has_docker; then
  if [ "$mode" = prod ]; then
    step "Starting the prod stack (release images rebuilt from the current code)"
    docker compose up -d --build --wait
  else
    step "Starting the dev stack"
    "${DEV_COMPOSE[@]}" up -d --wait
  fi
  ensure_workspace
elif inside_workspace; then
  step "Inside the dev container: using the services that are up (no Docker here to start them)"
else
  fail "Docker is needed to start the stack (or run this inside the dev container)."
fi

step "Waiting for both services"
wait_for_services

step "Story tests: mix test"
in_e2e "mix test$(quoted "${mix_args[@]+"${mix_args[@]}"}")"

if [ "$newman" = true ]; then
  step "Postman mirror: newman"
  in_e2e "newman run postman/banking.postman_collection.json \
    -e postman/devcontainer.postman_environment.json"
fi

step "✅ Stories passed"
