# Development image for the accounts, ledger and e2e apps: the toolchain only, no source.
# The repo is mounted at /workspace (see compose.yaml next to this file), for the workspace and
# the dev-mode services. The prod images are apps/<service>/Dockerfile.
FROM elixir:1.18.4-otp-27

# - inotify-tools: file_system's watcher on Linux
# - postgresql-client: psql, to peek at the databases
# - nodejs, npm: Newman (the Postman collection) and Redocly (the OpenAPI lint), through npx
# - jq: the curl examples in the service READMEs
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    inotify-tools \
    postgresql-client \
    nodejs \
    npm \
    jq \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force \
  && mix local.rebar --force

# Pre-fetch the CLIs, so the first `npx` needs no download.
RUN npm install --global newman@6 @redocly/cli@1

WORKDIR /workspace
