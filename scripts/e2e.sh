#!/usr/bin/env bash
# Runs the story tests (apps/e2e) and their Postman mirror against services that are already up.
#
#   scripts/e2e.sh                          # check the services, then `mix test`, then Newman
#   scripts/e2e.sh test/stories/transfer_test.exs
#   scripts/e2e.sh --skip-newman
#   ACCOUNTS_URL=http://staging:4000 LEDGER_URL=http://staging:4001 \
#     RABBITMQ_URL=amqp://banking:banking@staging:5672 scripts/e2e.sh
#
# It starts nothing. It pings Accounts, the Ledger and RabbitMQ first and stops if one is down.
# The URLs default to localhost, as in apps/e2e/config/config.exs. Needs Elixir, curl and
# Newman (or npx). Other arguments go to `mix test`.

set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "$0")/_common.sh"

newman=true
mix_args=()

for arg in "$@"; do
  case "$arg" in
    --skip-newman) newman=false ;;
    -h | --help) sed -n '2,12p' "$0"; exit 0 ;;
    *) mix_args+=("$arg") ;;
  esac
done

check_services

step "Story tests: mix test"
in_e2e mix test "${mix_args[@]+"${mix_args[@]}"}"

if [ "$newman" = true ]; then
  step "Postman mirror: newman"
  if command -v newman >/dev/null 2>&1; then
    runner=(newman)
  else
    need npx "Newman runs from npm; install Node, or pass --skip-newman."
    runner=(npx --yes newman)
  fi
  (cd apps/e2e && "${runner[@]}" run postman/banking.postman_collection.json \
    -e postman/local.postman_environment.json \
    --env-var "accounts_url=$ACCOUNTS_URL" \
    --env-var "ledger_url=$LEDGER_URL" \
    --env-var "rabbitmq_url=$RABBITMQ_MANAGEMENT_BASE" \
    --env-var "rabbitmq_user=$RABBITMQ_USER" \
    --env-var "rabbitmq_password=$RABBITMQ_PASSWORD")
fi

step "✅ Stories passed"
