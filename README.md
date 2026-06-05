# WebSearch

Agent-oriented web search and scraping service built with ASP.NET Core (.NET 10).

- **REST API** (`WebSearch.Api`) — `/search`, `/scrape` for custom agents
- **MCP stdio** (`WebSearch.Mcp`) — Claude Desktop / Cursor integration
- **Shared core** (`WebSearch.Application`) — business logic written once

## Quick start

### 1. Infrastructure (Docker)

```powershell
docker compose up -d redis searxng crawl4ai
```

PostgreSQL is optional for Week 1; enable it for request logging:

```powershell
docker compose up -d postgres
dotnet ef database update --project src/WebSearch.Application --startup-project src/WebSearch.Api
```

### 2. Configure

Copy `.env.example` to `.env` and fill in API keys as needed.

### 3. Run the API

```powershell
dotnet run --project src/WebSearch.Api
```

API listens on `http://localhost:5080` by default.

### 4. Verify

```powershell
curl "http://localhost:5080/search?query=aspnet+core"
curl -X POST http://localhost:5080/search -H "Content-Type: application/json" -d "{\"query\":\"asyncio最佳实践\"}"
curl -X POST http://localhost:5080/scrape -H "Content-Type: application/json" -d "{\"url\":\"https://example.com\"}"
curl http://localhost:5080/health
```

## MCP (stdio)

See [docs/mcp-client-config.md](docs/mcp-client-config.md) for Claude Desktop / Cursor configuration.

## Documentation

- [Architecture](docs/architecture.md)
- [Setup guide](docs/setup.md)
- [MCP client config](docs/mcp-client-config.md)

## Solution structure

```
src/
  WebSearch.Application/   # Shared services, models, caching
  WebSearch.Api/           # Minimal API (HTTP)
  WebSearch.Mcp/           # MCP stdio host
tests/
  WebSearch.Api.Tests/
services/
  crawl4ai/                # Python Crawl4AI sidecar
deploy/
  searxng/                 # SearXNG configuration
```
