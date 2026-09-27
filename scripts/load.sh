#!/usr/bin/env bash
# Runs the load test (mix e2e.load) against services that are already up.
#
#   scripts/load.sh
#   scripts/load.sh --rate 100 --duration 120 --accounts 50
#   scripts/load.sh --mix transfer=100
#   ACCOUNTS_URL=http://staging:4000 LEDGER_URL=http://staging:4001 \
#     RABBITMQ_URL=amqp://banking:banking@staging:5672 scripts/load.sh
#
# It starts nothing and sets no limits. To squeeze the local stack first (BEAM_CPUS=2.0
# BEAM_MEMORY=768m for the scaled scenario; `docker compose up -d --wait` takes them off):
#
#   docker compose -f docker-compose.yml -f docker-compose.load.yml up -d --build --wait ledger accounts
#
# It pings Accounts, the Ledger and RabbitMQ first and stops if one is down. The URLs default to
# localhost, as in apps/e2e/config/config.exs. Needs Elixir and curl. Arguments go to
# `mix e2e.load` (see `mix help e2e.load`). The JSON report lands in apps/e2e/load-results/.
# Watch the run on each service's /dashboard (apps/e2e/README.md, "Watch it on the dashboards").

set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "$0")/_common.sh"

case "${1:-}" in
  -h | --help) sed -n '2,18p' "$0"; exit 0 ;;
esac

check_services

printf '\n📈 Watch it on the dashboards (Metrics tab):\n   %s/dashboard/metrics\n   %s/dashboard/metrics\n' \
  "$ACCOUNTS_URL" "$LEDGER_URL"

report="load-results/$(date +%Y%m%d-%H%M%S).json"
step "Load test: mix e2e.load"
in_e2e mix e2e.load --out "$report" "$@"

printf '\n📝 apps/e2e/%s\n' "$report"
