# dockerfiles — VPS GitOps repo

This repo is the source of truth for everything that runs on the Hetzner VPS. Each
top-level directory is one independent "stack" (one or more containers managed by its
own `docker-compose.yml`). There is no orchestrator tying the stacks together — the
thing that glues them into one working host is a shared Docker network plus a
reverse proxy that auto-discovers containers on it.

Docker runs **rootless** under the `kovo` user on the host. Since a rootless daemon
has no systemd-managed autostart of its own, persistence across reboots is enabled
once via:

```
loginctl enable-linger kovo
```

This keeps `kovo`'s user session (and therefore the rootless docker daemon) alive in
the background even when nobody is logged in.

On the VPS the repo is checked out at `/home/kovo/docker/dockerfiles` — this exact
path is baked into `registry/docker-compose.yml`, so keep that checkout path if you
ever re-clone.

## Repo structure

```
dockerfiles/
├── nginx/                  # shared reverse proxy + TLS (the entry point for everything)
│   ├── docker-compose.yml
│   └── .env                # not committed — DOCKER_HOST_PATH override for rootless docker
│
├── registry/                # private Docker image registry used by the other stacks
│   └── docker-compose.yml
├── registry-config/
│   └── config.yml           # registry auth (htpasswd) + CORS for the registry-ui
│
├── kovo-space/               # personal site, single Rails container
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── run.sh
│   └── .env                  # not committed
│
└── paster-cloud/             # 3-tier app: postgres + spring backend + angular frontend
    ├── docker-compose.yml
    ├── dc                     # wrapper script: ordered up/down + pre-up hook
    ├── env.template           # committed placeholder, real secrets go in .env
    ├── .env                   # not committed
    ├── backend/
    │   ├── docker-compose.yml # legacy/standalone mysql compose, not used by main stack
    │   └── Dockerfile
    └── frontend/
        ├── Dockerfile
        ├── nginx.conf
        └── setenv.sh          # bakes container ENV vars into the Angular runtime
```

Every `.env` file is git-ignored (see `.gitignore`). Where one exists, only a
`*.env.template` / `env.template` with placeholder values is committed, e.g.
`paster-cloud/env.template`. Secrets live only on the host.

## How the reverse proxy + Let's Encrypt actually works

`nginx/docker-compose.yml` runs two containers and nothing else:

| Container | Image | Job |
|---|---|---|
| `nginx` | `nginxproxy/nginx-proxy:alpine` | Listens on host ports **80/443**, watches the Docker socket, and auto-generates an nginx vhost for every other container it can see. |
| `letsencrypt` | `nginxproxy/acme-companion` | Watches the same containers, requests/renews Let's Encrypt certs for them, and writes the cert files into a volume the `nginx` container reads from. |

Both containers mount the Docker socket (the `letsencrypt-companion`'s `nginx_proxy`
label tells `nginx-proxy` it's allowed to do this) and share four named volumes:
`certs`, `vhost.d`, `html`, `acme`. There is **no manual nginx config anywhere** —
the vhost + cert config is generated entirely from labels/env vars on other containers.

Because docker is rootless, the default `/var/run/docker.sock` doesn't exist for this
user — `nginx/.env` overrides it:

```
DOCKER_HOST_PATH=/run/user/1000/docker.sock
```

### How any other stack plugs into it

Any service that should be reachable from the internet (with auto-issued HTTPS) just
needs to:

1. Join the same external Docker network the proxy uses, named **`nginx-proxy`**.
2. Set four environment variables on that service:

   ```yaml
   environment:
     VIRTUAL_HOST: my-app.example.com      # domain nginx-proxy will route to this container
     VIRTUAL_PORT: 3000                     # port *inside* the container to proxy to
     LETSENCRYPT_HOST: my-app.example.com   # domain to request a cert for (usually == VIRTUAL_HOST)
     LETSENCRYPT_EMAIL: you@example.com     # ACME registration contact
   networks:
     - nginx-proxy
   ```

That's it — no restart of the `nginx` container, no manual config edit. `nginx-proxy`
sees the new container appear on the shared network, reads its labels/env vars, and
rewrites its config; `letsencrypt-companion` requests the cert the first time it sees
a new `LETSENCRYPT_HOST`.

`kovo-space` and `paster-cloud`'s backend/frontend both follow exactly this pattern —
see their `docker-compose.yml` for working examples.

Anything that should **not** be public (databases, internal APIs) simply stays off
the `nginx-proxy` network and doesn't set those env vars — e.g. `paster-cloud-db`
only joins the private `paster-cloud-private` network.

### One-time setup the compose files assume

Both `nginx-proxy` and `paster-cloud-private` are declared `external: true`, meaning
they must already exist before `docker compose up` is run for the first time:

```bash
docker network create nginx-proxy
docker network create paster-cloud-private
```

Bring `nginx/` up **first** (it owns ports 80/443) before bringing up anything that
depends on the `nginx-proxy` network.

## Apps, containers & networking at a glance

| App | Container | Networks connected to | Exposed ports (host:container) | Domain assigned |
|---|---|---|---|---|
| nginx | `nginx` | `nginx-proxy`, `default` | 80:80, 443:443 | — (this *is* the entry point for every domain below) |
| nginx | `letsencrypt` | `nginx-proxy` | — | — |
| registry | `registry` | default (project-local network, shared with `registry-ui` only) | 5000:5000 | — (no domain, raw IP:port) |
| registry | `registry-ui` | default (project-local network, shared with `registry` only) | 9080:80 | — (no domain, raw IP:port) |
| kovo-space | `kovo-space` | `nginx-proxy` | 3000:3000 | `kovo.space` |
| paster-cloud | `paster-cloud-db` | `paster-cloud-private` | 5432:5432 | — (internal only, not public) |
| paster-cloud | `paster-cloud-backend` | `nginx-proxy`, `paster-cloud-private` | 4004:4004 | `api.paster.cloud` |
| paster-cloud | `paster-cloud-frontend` | `nginx-proxy` | 4204:80 | `paster.cloud` |

Notes:
- "Domain assigned" reflects each service's `VIRTUAL_HOST`/`LETSENCRYPT_HOST` default in its
  `docker-compose.yml` — actual value can be overridden per-host via `.env`.
- Host port mappings are mostly irrelevant for the public-facing containers: traffic actually
  arrives via `nginx`'s 80/443 and gets proxied container-to-container over the `nginx-proxy`
  network to each service's `VIRTUAL_PORT`, not via the `ports:` mapping shown above.
- `paster-cloud-frontend`'s `ports: "4204:80"` doesn't match what its own `nginx.conf` listens
  on (`4204` inside the container, not `80`) — a pre-existing inconsistency in that compose file.
  It doesn't break anything in practice since `nginx-proxy` reaches it via `VIRTUAL_PORT=4204`
  over the internal network rather than through this host port mapping.
- `registry`/`registry-ui` are reachable only via their raw host ports (`<vps-ip>:5000` /
  `<vps-ip>:9080`) — they're intentionally not on `nginx-proxy`, so no domain or TLS applies.

## Stacks and their services

### `nginx/` — reverse proxy & TLS
- `nginx` (nginxproxy/nginx-proxy) — public entry point, ports 80/443
- `letsencrypt` (nginxproxy/acme-companion) — cert issuance/renewal
- Requires external network `nginx-proxy` to exist first.
- Must be running before any other stack that wants a public domain.

### `registry/` — private Docker image registry
- `registry` (registry:3) — port 5000, stores images pushed as `k0v0/kovo-docker-repo:*`
- `registry-ui` (joxit/docker-registry-ui) — port 9080, browser UI for the registry
- Auth via htpasswd (`registry-config/config.yml`, htpasswd file under `/auth` on host).
  `registry:3` (distribution v3) loads its config from **`/etc/distribution/config.yml`**,
  not the v2-era `/etc/docker/registry/config.yml` — the bind mount in
  `registry/docker-compose.yml` must target the v3 path or auth silently never engages
  (the container falls back to its baked-in default config with no auth at all).
- Not on the `nginx-proxy` network — reached directly via raw ports, not a domain/TLS.
- This registry is where the prebuilt images used by `kovo-space` and `paster-cloud`
  (`k0v0/kovo-docker-repo:<app>-<tag>`) come from — build/push happens outside this repo.

### `kovo-space/` — personal site (Rails)
- Single container, image pulled from the private registry.
- Joins `nginx-proxy`, sets `VIRTUAL_HOST`/`LETSENCRYPT_HOST` to `kovo.space`.
- Host volumes for sqlite databases and uploads (paths in `.env`).
- `Dockerfile`/`run.sh` are kept for local image builds; production uses the registry image.

### `paster-cloud/` — 3-tier app (Postgres + Spring Boot + Angular)
- `paster-cloud-db` (postgres:16) — only on the private `paster-cloud-private` network, not public.
- `paster-cloud-backend` (Spring Boot, custom image) — on both `nginx-proxy` and
  `paster-cloud-private`; public at `api.paster.cloud`.
- `paster-cloud-frontend` (Angular built into an nginx:alpine image) — on `nginx-proxy`
  only; public at `paster.cloud`; talks to the backend over `BACKEND_API`.
- `dc` script wraps `docker-compose up/down` to start db → backend → frontend in order
  with short sleeps, and calls a `pre_up_actions` hook (`~/scripts/gopnik-vault.sh`,
  external to this repo) before bringing the stack up — presumably to pull secrets
  into `.env` before compose reads it.
- `backend/docker-compose.yml` is a leftover standalone MySQL compose, not part of the
  active stack (the active stack uses Postgres, declared inline in the top-level compose).

## Adding a new project/stack

1. **Create a new top-level directory** named after the project, with its own
   `docker-compose.yml`.

2. **Decide what's public vs. internal.**
   - Public-facing service(s): add `networks: [nginx-proxy]` and the four env vars
     (`VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`).
     Point the domain's DNS A record at the VPS IP — that's all that's needed for
     `nginx-proxy`/`letsencrypt-companion` to pick it up and get a cert.
   - Internal-only service(s) (databases, etc.): give the stack its own external
     network (e.g. `myapp-private`) and don't put them on `nginx-proxy` or set the
     `VIRTUAL_*`/`LETSENCRYPT_*` vars. Create the network once with
     `docker network create myapp-private` before first `up`.

3. **Secrets**: put real values in a local `.env` next to the compose file (already
   git-ignored by the repo's `.gitignore`). Commit an `env.template` alongside it with
   placeholders, following `paster-cloud/env.template`'s style.

4. **Custom images**: if the app needs a build, add a `Dockerfile`. For
   anything non-trivial, prefer building the image elsewhere and pushing it to this
   VPS's private registry as `k0v0/kovo-docker-repo:<project>-<tag>`, then reference
   that tag in `docker-compose.yml` — this is what `kovo-space` and `paster-cloud` do,
   so the VPS only ever has to pull, not build.

5. **Startup order**: a plain `docker compose up -d` is enough for single-service
   stacks. If a service depends on another being ready first (e.g. a DB), either use
   `depends_on` with a healthcheck, or write a small wrapper script like
   `paster-cloud/dc` that brings services up in sequence with short sleeps.

6. **Bring it up**: ensure `nginx/` and any required external networks already exist,
   then `cd <project> && docker compose up -d`.

## CLAUDE.md

See [`CLAUDE.md`](./CLAUDE.md) for repo-specific conventions aimed at an AI assistant
working in this repo.