# ADR 0001: App container uses host network to support external Redis / PostgreSQL

## Status
Accepted

## Context
The install wizard detects whether Redis / PostgreSQL are already running on the host (port 6379 / 5432). If they are, it connects to them instead of starting new containers. This is the primary use case for single-VPS deployments where infra is shared across projects.

Bridge network makes this hard: the app container resolves `redis` / `postgres` via Docker DNS, not `localhost`, so external services on the host are unreachable without `extra_hosts` workarounds.

## Decision
The `app` service uses `network_mode: host`. Redis and PostgreSQL services are gated behind Compose profiles (`builtin-redis`, `builtin-postgres`). The wizard writes connection strings with `localhost` addresses into `.env`; the app reads them directly.

`crawl-svc` and `searxng` keep bridge network — they are always internal and have no external-service alternative.

## Consequences
- External Redis / PostgreSQL reuse works without workarounds.
- `app` container loses Docker network isolation (acceptable for single-tenant VPS).
- `crawl-svc` and `searxng` must be reached via `localhost:<port>` from the app, not via service names.
