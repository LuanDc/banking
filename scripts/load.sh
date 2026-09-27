#!/usr/bin/env bash
# Runs the load test (mix e2e.load) against the prod stack squeezed by docker-compose.load.yml.
#
#   scripts/load.sh                                   # base: 1 CPU / 512m per service
#   scripts/load.sh --scaled                          # scaled: 2 CPUs / 768m per service
#   scripts/load.sh --rate 100 --duration 120 --accounts 50
#   scripts/load.sh --scaled --mix transfer=100
#
# It rebuilds the release images from the current code and recreates ledger, accounts,
# Postgres and RabbitMQ with the limits, then runs the generator in the workspace container,
# outside the limits. BEAM_CPUS and BEAM_MEMORY override the scenario. Other arguments go to
# `mix e2e.load` (see `mix help e2e.load`). The JSON report lands in apps/e2e/load-results/.
#
# The limits stay on afterwards; `docker compose up -d --wait` takes them off.

set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "$0")/_common.sh"

scenario=base
load_args=()

for arg in "$@"; do
  case "$arg" in
    --scaled) scenario=scaled ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) load_args+=("$arg") ;;
  esac
done

has_docker || fail "The load test runs from the host: it needs Docker to set the container limits."

if [ "$scenario" = scaled ]; then
  export BEAM_CPUS="${BEAM_CPUS:-2.0}" BEAM_MEMORY="${BEAM_MEMORY:-768m}"
fi

LOAD_COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.load.yml)
services=(ledger accounts postgres rabbitmq)

step "Starting the prod stack with the $scenario limits (BEAM ${BEAM_CPUS:-1.0} CPU · ${BEAM_MEMORY:-512m})"
"${LOAD_COMPOSE[@]}" up -d --build --wait ledger accounts
ensure_workspace

step "Limits in place"
for service in "${services[@]}"; do
  docker inspect -f "{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}}" \
    "$("${LOAD_COMPOSE[@]}" ps -q "$service")" |
    awk -v s="$service" '{ printf "   %-9s %s CPU · %d MiB\n", s, $1 / 1e9, $2 / 1048576 }'
done

# A container that hit its CPU quota shows as throttled periods in its cgroup.
throttled() {
  "${LOAD_COMPOSE[@]}" exec -T "$1" cat /sys/fs/cgroup/cpu.stat 2>/dev/null |
    awk '$1 == "nr_throttled" { print $2 }'
}

# Indexed like `services`: macOS still ships bash 3.2, without associative arrays.
throttled_before=()
for service in "${services[@]}"; do throttled_before+=("$(throttled "$service")"); done

step "Waiting for both services"
wait_for_services

report="load-results/$(date +%Y%m%d-%H%M%S)-$scenario.json"
step "Load test: mix e2e.load"
status=0
in_e2e "mix e2e.load --out $report$(quoted "${load_args[@]+"${load_args[@]}"}")" || status=$?

step "CPU periods throttled during the run (the first to climb hit its quota)"
for i in "${!services[@]}"; do
  after="$(throttled "${services[$i]}")"
  printf '   %-9s %s\n' "${services[$i]}" "$(( ${after:-0} - ${throttled_before[$i]:-0} ))"
done

step "Memory at the end"
containers=()
while read -r id; do containers+=("$id"); done < <("${LOAD_COMPOSE[@]}" ps -q "${services[@]}")
docker stats --no-stream --format '   {{.Name}}\t{{.MemUsage}}' "${containers[@]}"

printf '\n📝 apps/e2e/%s · take the limits off: docker compose up -d --wait\n' "$report"
exit "$status"
