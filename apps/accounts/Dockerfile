# Production image: the service as a `mix release`, run by the root docker-compose.yml.
# Build context: this directory.
#
#   docker build -t banking-accounts apps/accounts
#
# The builder has the same Elixir and OTP as the dev image (.devcontainer/Dockerfile), on
# Debian bookworm; the runner is the same Debian, so the release finds the OpenSSL and libc it
# was built against. Tags: https://hub.docker.com/r/hexpm/elixir/tags
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.16
ARG DEBIAN_VERSION=bookworm-20260824-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV="prod"

# Deps first, so a change in lib/ does not fetch and compile them again.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# The compile-time config, before the deps, so a change to it recompiles them.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
RUN mix compile

# Read when the release starts, so a change to it needs no recompiling.
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

# curl: the healthcheck in docker-compose.yml
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

# Only the release: no Elixir, Mix or source code.
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/accounts ./

USER nobody

# bin/setup (Accounts.Release.setup/0) prepares the databases before the first start; see
# docker-compose.yml.
CMD ["/app/bin/server"]
