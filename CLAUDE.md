# CLAUDE.md

Guidance for Claude Code when working in this repo.

## What this repo is

A GitOps config repo for one Hetzner VPS, not an application codebase. There is no
build/test/lint command to run here — changes are docker-compose files, Dockerfiles,
and config, deployed by pulling this repo onto the VPS and running `docker compose up`
in the relevant directory. Treat every directory at the repo root as an independent
stack; there is no umbrella compose file joining them.

## Things that are easy to get wrong here

- **Docker is rootless**, running as user `kovo` on the host. The default
  `/var/run/docker.sock` does not apply to containers that need socket access — see
  `nginx/.env`'s `DOCKER_HOST_PATH=/run/user/1000/docker.sock`. If you add another
  container that needs the docker socket, it needs the same override, not the default.
- **`nginx-proxy` + `letsencrypt-companion` (in `nginx/`) is the only reverse proxy.**
  There is no per-app nginx vhost config to write. Public reachability + HTTPS comes
  entirely from a service joining the external `nginx-proxy` Docker network and
  setting `VIRTUAL_HOST` / `VIRTUAL_PORT` / `LETSENCRYPT_HOST` / `LETSENCRYPT_EMAIL`
  env vars. Don't suggest writing an nginx.conf vhost for a new public service — it's
  unnecessary and not how anything else in this repo does it.
- **Networks marked `external: true`** (`nginx-proxy`, `paster-cloud-private`) are not
  created by compose. They must already exist on the host (`docker network create
  ...`) before `docker compose up` works. If you add a new private network for a new
  stack, say so explicitly rather than assuming compose will create it.
- **`.env` files are intentionally not committed** (see `.gitignore`'s `.env` rule).
  Don't add real secrets to git. When a stack needs configurable secrets, follow
  `paster-cloud`'s pattern: commit `env.template` with placeholders, keep the real
  `.env` local/host-only.
- **Images are often prebuilt and pulled from a private registry**, not built on the
  VPS. `kovo-space` and `paster-cloud` reference `k0v0/kovo-docker-repo:<app>-<tag>`
  images served by `registry/`. The `Dockerfile`s in those directories are for
  building those images elsewhere (or locally), not something the VPS runs at deploy
  time. Don't assume `docker compose up` triggers a build unless a compose file
  actually has a `build:` key (none currently do).
- **`registry/docker-compose.yml` hardcodes the host checkout path**
  (`/home/kovo/docker/dockerfiles/registry-config/config.yml`). If the repo is ever
  cloned to a different path on the VPS, that bind mount breaks.
- **`paster-cloud/backend/docker-compose.yml`** is a leftover standalone MySQL compose
  and is not part of the live stack — the real stack (top-level
  `paster-cloud/docker-compose.yml`) uses Postgres. Don't treat the backend
  subdirectory's compose as authoritative for how the backend actually runs.
- **`paster-cloud/dc`** is the intended way to bring that stack up/down (ordered
  start: db → backend → frontend, plus a `pre_up_actions` hook calling an external
  `~/scripts/gopnik-vault.sh`, presumably to populate `.env` from a secrets vault
  before compose reads it). That script lives outside this repo — don't assume it's
  inspectable here.

## When adding a new stack

Follow the existing pattern (see README.md "Adding a new project/stack"): one new
top-level directory, its own `docker-compose.yml` + `.env`/`env.template`, public
services on the `nginx-proxy` network with the four `VIRTUAL_*`/`LETSENCRYPT_*` vars,
internal services on a private external network created up front. Don't introduce a
different reverse-proxy or TLS mechanism for a single stack — route it through the
existing `nginx-proxy` setup like everything else.