# WebSearch — Domain Glossary

## Terms

### Scrape Provider
A backend capable of fetching a URL and returning its content as clean Markdown. The service tries providers in order and uses the first successful result.

Current provider chain: **crawl-svc** (local, free) → **Firecrawl** (paid fallback).

### Search Provider
A backend capable of executing a keyword query and returning a ranked list of results.

Current provider chain: **SearXNG** (local, free) → **Tavily** (paid fallback, fires when SearXNG quality is insufficient).

### Tavily Fallback
Fires when SearXNG returns < 4 results **or** average score < 0.3. Results are merged with SearXNG results, deduplicated, and re-ranked. `SearchResponse.Source` = `"searxng+tavily"` when Tavily contributed. Skipped entirely if `TAVILY_API_KEY` is absent.

### crawl-svc
Self-hosted Python sidecar. Fetches HTML via httpx (static only — Playwright removed), then cleans with trafilatura. Returns Markdown or null. JS-heavy pages fall through to Firecrawl.

### Quality Gate
Minimum content standards applied after trafilatura extraction. A result failing the gate is treated as if the provider returned nothing.
Current thresholds: ≥ 200 chars, ≥ 2 paragraphs, link density ≤ 50%.

### MCP
Out of scope for current iteration. Will be reconsidered after REST API is stable. Do not wire up MCP endpoints until explicitly revisited.

### Scrape Fallback Chain
`crawl-svc (httpx only)` → `Firecrawl (paid)`. Playwright removed. Jina removed permanently.

### Network Mode
`app` container runs `network_mode: host`. crawl-svc and searxng use bridge network (`app-net`), reachable from app via `localhost:<port>`. Redis and PostgreSQL are behind Compose profiles (`builtin-redis`, `builtin-postgres`) so the wizard can skip them when external instances exist.

### Install Wizard
Interactive setup in `deploy/setup-vps.sh`. Collects: APP_PORT, Redis (builtin vs external + optional password), PostgreSQL (builtin vs external), SearXNG secret (auto-generated), TAVILY_API_KEY, FIRECRAWL_API_KEY, cache TTLs, domain + HTTPS. Writes `.env` then calls `compose_up`.
