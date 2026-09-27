# Banking lab · Event Sourcing in Elixir

![Elixir](https://img.shields.io/badge/Elixir-1.18-4B275F?logo=elixir&logoColor=white)
![Phoenix](https://img.shields.io/badge/Phoenix-1.7-FD4F00?logo=phoenixframework&logoColor=white)
![Commanded](https://img.shields.io/badge/Commanded-1.4-6E4A7E)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)
![RabbitMQ](https://img.shields.io/badge/RabbitMQ-4-FF6600?logo=rabbitmq&logoColor=white)
![OpenAPI](https://img.shields.io/badge/OpenAPI-3.1-6BA539?logo=openapiinitiative&logoColor=white)

> 🧪 **This is a learning lab.** I built it to learn Event Sourcing, CQRS and DDD on a small
> core-banking domain: accounts, money transfers and a double-entry ledger.
> I'm sharing it as a **reference** for anyone walking the same path, and I'd love your
> **feedback** ([how to give it](#feedback)).

## The idea in one picture

Two bounded contexts, each one its own Phoenix service with its own event store. They share no code
and no database, and they talk only through RabbitMQ.

```mermaid
flowchart LR
    U(["👤 Customer / back office"])

    subgraph AC["accounts · :4000"]
        A["CustomerAccount<br/>lifecycle, balance, transfer saga"]
    end

    subgraph LG["ledger · :4001"]
        L["TransactionBatch<br/>double entry: debits = credits"]
    end

    MQ[["🐇 RabbitMQ"]]

    U -->|"HTTP commands"| A
    A -->|"commands<br/>ledger.commands"| MQ --> L
    L -->|"events<br/>ledger.events"| MQ
    MQ --> A

    classDef svc fill:#FFE082,stroke:#C8A300,color:#14202B
    classDef mq fill:#FFCC80,stroke:#E65100,color:#14202B
    class A,L svc
    class MQ mq
```

A transfer reserves money in `accounts`, is booked in the `ledger`, and is then confirmed or
compensated. There is no distributed transaction, only events and a saga.

## Where to go next

### 📐 The design: [`docs/event_storming.md`](docs/event_storming.md)

Start here to understand *why* the code looks the way it does.

| I want to… | Read |
| --- | --- |
| Learn the sticky-note colors | [1 · Legend](docs/event_storming.md#1-sticky-note-legend) |
| See an account's life at a glance | [2 · Big Picture](docs/event_storming.md#2-big-picture--timeline-of-the-pivotal-events) |
| Understand the account FSM | [3 · Account Management](docs/event_storming.md#3-process-level--account-management-context) |
| Understand the double-entry ledger | [4 · Ledger](docs/event_storming.md#4-process-level--ledger-context) |
| Follow a transfer end to end, including failures | [5 · TransferMoney flow](docs/event_storming.md#5-design-level--end-to-end-transfermoney-flow) |
| See how the two contexts relate | [6 · Context Map](docs/event_storming.md#6-context-map) |
| Browse every command, event and policy | [7 · Inventory](docs/event_storming.md#7-inventory-of-commands-events-and-aggregates) |
| See the open questions and how each was settled | [8 · Hotspots](docs/event_storming.md#8-hotspots--open-decisions) |
| Read the trade-offs (D1…D17) | [10 · Design decisions](docs/event_storming.md#10-design-decisions) |

### 🧩 The services

Each service has its own README with how it works inside.

| | [🏦 accounts](apps/accounts/README.md) | [📒 ledger](apps/ledger/README.md) |
| --- | --- | --- |
| Role | Account lifecycle, available balance, transfer saga | Immutable double-entry book, source of truth for balances |
| Tech stack | [Stack](apps/accounts/README.md#tech-stack) | [Stack](apps/ledger/README.md#tech-stack) |
| Run in dev | [Guide](apps/accounts/README.md#run-in-dev) | [Guide](apps/ledger/README.md#run-in-dev) |
| HTTP API + Swagger download | [API](apps/accounts/README.md#http-api) | [API](apps/ledger/README.md#http-api) |
| Aggregates | [CustomerAccount](apps/accounts/README.md#aggregate) | [TransactionBatch · LedgerAccount](apps/ledger/README.md#aggregates) |
| Commands | [13 commands](apps/accounts/README.md#commands) | [3 commands](apps/ledger/README.md#commands) |
| Events | [15 events](apps/accounts/README.md#events) | [4 events](apps/ledger/README.md#events) |
| Database tables | [Tables](apps/accounts/README.md#database-tables) | [Tables](apps/ledger/README.md#database-tables) |
| Queues | [Queues](apps/accounts/README.md#queues) | [Queues](apps/ledger/README.md#queues) |

### 🎬 The stories: [`apps/e2e`](apps/e2e/README.md)

End-to-end tests that drive both running services through their APIs and RabbitMQ: deposits,
transfers, compensation, closing, and redelivered messages. Each one checks that both books agree.
The same steps drive a load test, which ends with the same check.

| I want to… | Read |
| --- | --- |
| See how a story test works | [How a story works](apps/e2e/README.md#how-a-story-works) |
| Run the suite | [Run it](apps/e2e/README.md#run-it) |
| Browse what is covered | [Stories](apps/e2e/README.md#stories) |
| Replay them by hand in Postman | [Replay them in Postman](apps/e2e/README.md#replay-them-in-postman) |
| Load-test the stack and check both books after | [Load test](apps/e2e/README.md#load-test) |

## Run it locally

> 🐳 **Only Docker is needed.** Elixir, Postgres, RabbitMQ and Node all run in containers, so
> nothing else goes on your machine.

### What you need

| | Tool | Why |
| --- | --- | --- |
| ✅ | [Docker](https://docs.docker.com/get-docker/) (Engine 25+ or Docker Desktop) | runs everything |
| ⭐ | [VS Code](https://code.visualstudio.com/) + [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension | the editor inside the container (optional) |

### Open it in the dev container

1. Clone the repo and open the folder in VS Code.
2. When VS Code offers **Reopen in Container**, click it. You can also run it from the command
   palette (`F1` → *Dev Containers: Reopen in Container*).
3. Wait for the first build. It builds the dev image and compiles both services, so it takes a
   few minutes. Later starts take seconds.
4. Once the window reopens, the terminal is inside the `workspace` container, in `/workspace`,
   and both services are already running in dev mode.

Check that everything is up:

```bash
curl -s http://ledger:4001/api/trial-balance      # {"balanced":true, ...}
```

> 🧩 **Bring your own extensions.** The container comes with the Elixir, Phoenix, YAML and
> Mermaid extensions from [`devcontainer.json`](.devcontainer/devcontainer.json). Themes and
> keymaps keep working from your machine. To add the extensions you use locally, such as an AI
> agent:
>
> - **Once:** open the command palette (`F1`), search for *Install Local Extensions*, and pick
>   the ones you want. The Extensions view has the same action behind its cloud button.
> - **Every time:** list them in your own VS Code user settings. They are then installed in
>   every dev container on top of the defaults:
>
>   ```jsonc
>   "dev.containers.defaultExtensions": ["anthropic.claude-code", "eamodio.gitlens"]
>   ```

### What starts

```mermaid
flowchart LR
    subgraph HOST["💻 your machine"]
        VS["VS Code"]
        BR["browser / Postman"]
    end

    subgraph DC["🐳 docker compose · project banking"]
        WS["workspace<br/>editor, tests, e2e"]
        ACC["accounts :4000"]
        LED["ledger :4001"]
        PG[("postgres :5432")]
        MQ[["rabbitmq :5672 · :15672"]]
        SW["swagger-ui :8080"]
    end

    VS -.attached.-> WS
    BR -->|localhost ports| ACC & LED & SW & MQ
    WS --> ACC & LED & PG & MQ
    ACC --> PG & MQ
    LED --> PG & MQ

    classDef svc fill:#FFE082,stroke:#C8A300,color:#14202B
    classDef infra fill:#FFCC80,stroke:#E65100,color:#14202B
    class ACC,LED svc
    class PG,MQ infra
```

The two services run in one of two modes, on the same ports and the same Postgres and RabbitMQ:

| | 🛠️ Dev | 🚀 Prod |
| --- | --- | --- |
| For | everyday development | the e2e stories and load tests |
| Started by | the dev container, or both compose files | `docker compose up -d --build --wait` (root file only) |
| Runs | `mix phx.server` from the mounted source, with the dev image | a `mix release` built by `apps/<service>/Dockerfile` |
| A code change | reloads on the next request | needs `--build` |
| Setup on start | `mix setup` | `bin/setup` (`<App>.Release.setup/0`, the same steps) |
| Databases | `*_dev` | `*_prod` |

- 🔀 **One mode at a time.** Both share the project name, so starting either recreates `ledger`
  and `accounts` in its mode. The workspace keeps running in both.
- **ledger** starts first. Its setup creates the databases and seeds the bank's
  `pix-settlement` account, and the ledger declares the RabbitMQ queue that accounts sends
  commands to.
- **accounts** starts once the ledger is healthy.
- Each app keeps its `deps`, `_build` and dialyzer PLTs in Docker volumes, so they never mix
  with a build on your machine.

The same ports are published on your machine:

| Service | From your machine | From the workspace container |
| --- | --- | --- |
| 🏦 accounts API | http://localhost:4000/api | http://accounts:4000/api |
| 📒 ledger API | http://localhost:4001/api | http://ledger:4001/api |
| 📖 Swagger UI (both specs) | http://localhost:8080 | · |
| 🐇 RabbitMQ management | http://localhost:15672 (`banking` / `banking`) | http://rabbitmq:15672 |
| 📈 Dashboards ([what they show](apps/e2e/README.md#watch-it-on-the-dashboards)) | http://localhost:4000/dashboard · http://localhost:4001/dashboard (`banking` / `banking`) | http://accounts:4000/dashboard · http://ledger:4001/dashboard |
| 🐘 Postgres | `localhost:5432` (`postgres` / `postgres`) | `postgres:5432` |

### Work inside the container

The workspace container already points `PGHOST`, `RABBITMQ_URL`, `ACCOUNTS_URL` and `LEDGER_URL`
at the other containers, so the usual commands just work:

| I want to… | Run |
| --- | --- |
| 🧪 Run a service's tests | `cd apps/accounts && mix test` (or `apps/ledger`) |
| 🔍 Run the quality checks | `mix quality` in the service's folder |
| 🎬 Run the e2e stories | `scripts/e2e.sh` (or `cd apps/e2e && mix test`), against whichever mode is up |
| 📈 Run the load test | `scripts/load.sh` (or `cd apps/e2e && mix e2e.load`) |
| 📮 Replay the Postman collection | `newman run apps/e2e/postman/banking.postman_collection.json -e apps/e2e/postman/devcontainer.postman_environment.json` |
| 📐 Lint an OpenAPI spec | `npx @redocly/cli@1 lint apps/accounts/priv/openapi.yaml` |
| 🐘 Open a SQL shell | `psql -U postgres -d accounts_dev` (password `postgres`; `accounts_prod` in prod mode) |

The services' logs don't go to this terminal. Follow them from your machine with
`docker compose logs -f accounts ledger`.

### Without VS Code

The same containers run with Docker alone. From the repo root:

```bash
# The whole stack plus the workspace container
docker compose -f docker-compose.yml -f .devcontainer/compose.yaml up -d --wait

# A shell inside it, for the commands above
docker compose -f docker-compose.yml -f .devcontainer/compose.yaml exec workspace bash
```

### Switch modes

From your machine, in the repo root. The workspace, and VS Code attached to it, keep running:

```bash
# 🚀 Prod: rebuild the release images from the current code, then recreate the services
docker compose up -d --build --wait ledger accounts

# 🛠️ Back to dev
docker compose -f docker-compose.yml -f .devcontainer/compose.yaml up -d --wait ledger accounts
```

To run only the prod stack, with no workspace, `docker compose up -d --build --wait` is enough.

### Run the stories and the load test

Two scripts in the repo root run the tests against services that are already up. They start
nothing: first they ping the services and stop if one is down. They run the same on your machine
(with Elixir), in the workspace container or against another server, with `ACCOUNTS_URL`,
`LEDGER_URL` and `RABBITMQ_URL` pointing at it:

| I want to… | Run |
| --- | --- |
| 🎬 Run the e2e stories and their Postman mirror | `docker compose up -d --build --wait`, then `scripts/e2e.sh` ([details](apps/e2e/README.md#run-it)) |
| 📈 Load-test under the limits below | start the stack with them (next section), then `scripts/load.sh` ([details](apps/e2e/README.md#load-test)) |

### Limit resources for a load test

[`docker-compose.load.yml`](docker-compose.load.yml) squeezes the prod stack into a small cloud
footprint. It adds CPU quotas and memory limits with no swap, and leaves Swagger UI out. Start
the stack with it before `scripts/load.sh`:

```bash
# 📉 Base: 1 CPU per service
docker compose -f docker-compose.yml -f docker-compose.load.yml up -d --build --wait ledger accounts

# 📈 Scaled: 2 CPUs per service, to see whether throughput follows
BEAM_CPUS=2.0 BEAM_MEMORY=768m \
  docker compose -f docker-compose.yml -f docker-compose.load.yml up -d --build --wait ledger accounts
```

| Container | 📉 Base | 📈 Scaled | Cloud look-alike |
| --- | --- | --- | --- |
| ledger | 1 CPU · 512 MiB | 2 CPUs · 768 MiB | a small Fargate task |
| accounts | 1 CPU · 512 MiB | 2 CPUs · 768 MiB | a small Fargate task |
| postgres | 1 CPU · 1 GiB | same | `db.t4g.micro` |
| rabbitmq | 1 CPU · 512 MiB | same | a micro broker |
| **Total** | **4 CPUs · 2.5 GiB** | **6 CPUs · 3 GiB** | |

- ⚖️ **Whole CPUs only.** A limit is a CFS quota, not a pinned core. The BEAM runs one scheduler
  per CPU of quota. With a fraction, its threads use up the quota early and are frozen together
  until the next 100 ms period.
- 🎯 **Leave room for the load generator.** Whatever the stack doesn't take is left to the load
  generator. If the generator runs out of CPU, it becomes the bottleneck you measure. The scaled
  scenario leaves 2 CPUs on an 8-CPU Docker host.
- 🔎 **While it runs**, watch `docker stats`, then check `nr_throttled` in each container's
  `/sys/fs/cgroup/cpu.stat`: the one that climbs hit its quota first. The RabbitMQ UI shows
  queues backing up and blocked publishers.
- ↩️ **Back to normal:** `docker compose up -d --wait ledger accounts` recreates the services
  without the limits. `postgres` and `rabbitmq` keep theirs until you recreate them too, for
  example with `docker compose up -d --wait`.

### Stop, reset, troubleshoot

| Situation | Do |
| --- | --- |
| ⏸️ Stop everything, keep the data | `docker compose down` (VS Code also stops it when you close the window) |
| 🔁 Changed a service's code, in prod mode | `docker compose up -d --build --wait` rebuilds its image |
| 🧹 Start from scratch: data, deps and builds | `docker compose -f docker-compose.yml -f .devcontainer/compose.yaml down -v` |
| 🐢 `--wait` or VS Code seems stuck on the first run | it is compiling: `docker compose logs -f ledger accounts` |
| 🚫 A port is already in use (5432, 5672, 4000…) | stop whatever is using it on your machine, e.g. a local Postgres |
| 🔁 Changed the Dockerfile or `devcontainer.json` | *Dev Containers: Rebuild Container* |

Prefer your own Elixir on the host? Each service's [run in dev](apps/accounts/README.md#run-in-dev)
guide shows how to run just the infrastructure in Docker.

## Repository layout

```
.
├── docs/event_storming.md   # the design: event storming, context map, decisions D1…D17
├── apps/
│   ├── accounts/            # Account Management Context (Phoenix service)
│   ├── ledger/              # Ledger Context (Phoenix service)
│   └── e2e/                 # story tests and the load test, across both running services
├── scripts/                 # e2e.sh and load.sh: check the services, then run the stories or the load test
├── .devcontainer/           # dev image, dev-mode services and the workspace container for VS Code
├── docker-compose.yml       # the whole stack: Postgres, RabbitMQ, Swagger UI, both services (prod)
├── docker-compose.load.yml  # resource limits on top of it, for load tests
└── CLAUDE.md                # conventions for AI-assisted work on the repo
```

## Feedback

This is a study project, so questions and critiques are the point. 💬

- Something in the model looks wrong, or you would have decided a [trade-off](docs/event_storming.md#10-design-decisions) differently? Open an issue.
- A hotspot I missed? I'd love to hear about it.
- Found it useful? A ⭐ tells me it helped.
