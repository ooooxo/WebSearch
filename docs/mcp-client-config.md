# MCP Client Configuration

WebSearch exposes two tools over **stdio MCP**:

- `web_search` — search via SearXNG
- `web_scrape` — scrape URL with Crawl4AI → Firecrawl → Jina fallback

## Prerequisites

Start infrastructure before using MCP tools:

```powershell
docker compose up -d redis searxng crawl4ai
```

## Claude Desktop

Edit `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "websearch": {
      "command": "dotnet",
      "args": ["run", "--project", "E:/AllProjectFile/WebSearch/src/WebSearch.Mcp"],
      "env": {
        "Redis__Connection": "localhost:6379",
        "SearXng__BaseUrl": "http://localhost:8080",
        "Crawl4Ai__BaseUrl": "http://localhost:8001",
        "ConnectionStrings__Postgres": "Host=localhost;Port=5432;Database=websearch;Username=websearch;Password=websearch"
      }
    }
  }
}
```

Restart Claude Desktop after saving.

## Cursor

Add to Cursor MCP settings (`.cursor/mcp.json` in project or user settings):

```json
{
  "mcpServers": {
    "websearch": {
      "command": "dotnet",
      "args": ["run", "--project", "E:/AllProjectFile/WebSearch/src/WebSearch.Mcp"],
      "env": {
        "Redis__Connection": "localhost:6379",
        "SearXng__BaseUrl": "http://localhost:8080",
        "Crawl4Ai__BaseUrl": "http://localhost:8001"
      }
    }
  }
}
```

## Notes

- MCP uses **stderr** for logs; never write debug output to stdout.
- Paths use forward slashes on Windows for JSON compatibility.
- For production, prefer `dotnet run --configuration Release` or publish a self-contained binary and point `command` to the executable.
