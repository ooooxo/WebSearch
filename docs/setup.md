# Setup Guide

## Prerequisites

| Tool | Version |
|------|---------|
| .NET SDK | 10.0.x |
| Docker + Docker Compose | Latest (for infrastructure) |
| Python 3.11+ | Optional (local Crawl4AI dev only) |

Verify:

```powershell
dotnet --version
docker compose version
```

## Port map

| Service | Port |
|---------|------|
| WebSearch.Api | 5080 |
| Crawl4AI Python | 8001 |
| SearXNG | 8080 |
| Redis | 6379 |
| PostgreSQL | 5432 |

## Environment variables

Copy `.env.example` to `.env`. ASP.NET Core reads env vars with `__` as section separator.

| Variable | Maps to | Default |
|----------|---------|---------|
| `REDIS_CONNECTION` | `Redis:Connection` | `localhost:6379` |
| `POSTGRES_CONNECTION` | `ConnectionStrings:Postgres` | see `.env.example` |
| `SEARXNG_BASE_URL` | `SearXng:BaseUrl` | `http://localhost:8080` |
| `CRAWL4AI_BASE_URL` | `Crawl4Ai:BaseUrl` | `http://localhost:8001` |
| `JINA_API_KEY` | `Jina:ApiKey` | (empty) |
| `FIRECRAWL_API_KEY` | `Firecrawl:ApiKey` | (empty) |
| `CACHE_SEARCH_TTL` | `Cache:SearchTtlSeconds` | `3600` |
| `CACHE_SCRAPE_TTL` | `Cache:ScrapeTtlSeconds` | `86400` |

## Local development

### Start infrastructure

```powershell
docker compose up -d redis searxng crawl4ai
```

For request logging (Week 2+):

```powershell
docker compose up -d postgres
dotnet ef database update --project src/WebSearch.Application --startup-project src/WebSearch.Api
```

### Run API

```powershell
dotnet run --project src/WebSearch.Api
```

### Run MCP (stdio)

```powershell
dotnet run --project src/WebSearch.Mcp
```

Do not use `Console.WriteLine` in the MCP host — stdout is the MCP transport.

## NuGet packages

**WebSearch.Application**

- `Microsoft.Extensions.Http`
- `Microsoft.Extensions.Options.ConfigurationExtensions`
- `StackExchange.Redis`
- `Npgsql.EntityFrameworkCore.PostgreSQL` (logging)
- `Microsoft.EntityFrameworkCore`

**WebSearch.Api**

- `AspNetCore.HealthChecks.Redis`
- `AspNetCore.HealthChecks.NpgSql`
- `Microsoft.AspNetCore.OpenApi`

**WebSearch.Mcp**

- `ModelContextProtocol`
- `Microsoft.Extensions.Hosting`

## Troubleshooting

### SearXNG returns empty results

Ensure `deploy/searxng/settings.yml` has `search.formats` including `json`.

### Crawl4AI container slow on first request

First crawl downloads Chromium. Subsequent requests are faster.

### Redis connection refused

Confirm `docker compose ps` shows redis running on port 6379.

### MCP tools not appearing in Claude Desktop

- Check `docs/mcp-client-config.md` paths
- Restart Claude Desktop after config change
- Verify infrastructure is reachable from the MCP process env vars
