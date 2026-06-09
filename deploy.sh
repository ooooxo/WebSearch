#!/usr/bin/env bash
# WebSearch 一键部署脚本
# 用法: bash deploy.sh [--no-cache] [--down]
set -euo pipefail

# ── 颜色 ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn ]${NC} $*"; }
info() { echo -e "${CYAN}[ info ]${NC} $*"; }
die()  { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NO_CACHE=""
DO_DOWN=false
for arg in "$@"; do
  case "$arg" in
    --no-cache) NO_CACHE="--no-cache" ;;
    --down)     DO_DOWN=true ;;
  esac
done

# ── 停止并清理 ──────────────────────────────────────────────────────────
if $DO_DOWN; then
  log "Stopping and removing all containers..."
  docker compose down -v
  exit 0
fi

# ── 前置检查 ────────────────────────────────────────────────────────────
command -v docker  >/dev/null 2>&1 || die "docker not found. Install Docker first."
docker compose version >/dev/null 2>&1 || die "docker compose plugin not found."

# ── 生成 .env ───────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  warn ".env not found — generating from .env.example with random secrets..."
  cp .env.example .env

  gen_secret() {
    openssl rand -hex "${1:-32}" 2>/dev/null \
      || tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c "$((${1:-32} * 2))" \
      || date +%s%N | sha256sum | head -c "$((${1:-32} * 2))"
  }

  SEARXNG_SECRET="$(gen_secret 32)"
  POSTGRES_PASSWORD="$(gen_secret 16)"

  # macOS / Linux compatible sed
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "s|^SEARXNG_SECRET=.*|SEARXNG_SECRET=${SEARXNG_SECRET}|" .env
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
  else
    sed -i '' "s|^SEARXNG_SECRET=.*|SEARXNG_SECRET=${SEARXNG_SECRET}|" .env
    sed -i '' "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
  fi

  warn "Secrets written to .env — edit TAVILY_API_KEY / FIRECRAWL_API_KEY if needed."
else
  info "Using existing .env"
fi

# ── 拉取基础镜像 ─────────────────────────────────────────────────────────
log "Pulling base images..."
docker pull redis:7-alpine        &
docker pull postgres:16-alpine    &
docker pull searxng/searxng:latest &
wait
log "Base images ready."

# ── 构建自定义镜像 ────────────────────────────────────────────────────────
log "Building application images (crawl-svc + app)..."
log "  Note: crawl-svc installs Playwright + Chromium (~500 MB), this may take a few minutes."
docker compose build $NO_CACHE

# ── 启动基础设施 ──────────────────────────────────────────────────────────
log "Starting infrastructure (redis, postgres, searxng)..."
docker compose up -d redis postgres searxng

# ── 等待 Redis ────────────────────────────────────────────────────────────
log "Waiting for Redis..."
until docker compose exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; do
  printf '.'; sleep 1
done
echo; log "Redis is ready."

# ── 等待 PostgreSQL ───────────────────────────────────────────────────────
log "Waiting for PostgreSQL..."
until docker compose exec -T postgres pg_isready -U websearch -d websearch 2>/dev/null; do
  printf '.'; sleep 1
done
echo; log "PostgreSQL is ready."

# ── 启动 crawl-svc ────────────────────────────────────────────────────────
log "Starting crawl-svc (Playwright cold start ~30s)..."
docker compose up -d crawl-svc

WAIT=0
until docker compose exec -T crawl-svc curl -sf http://localhost:8001/health >/dev/null 2>&1; do
  printf '.'; sleep 2; WAIT=$((WAIT+2))
  [[ $WAIT -ge 120 ]] && die "crawl-svc failed to start. Run: docker compose logs crawl-svc"
done
echo; log "crawl-svc is ready."

# ── 启动主应用 ────────────────────────────────────────────────────────────
log "Starting app (C# + MCP SSE)..."
docker compose up -d app

WAIT=0
until curl -sf "http://localhost:3000/health/live" >/dev/null 2>&1; do
  printf '.'; sleep 2; WAIT=$((WAIT+2))
  [[ $WAIT -ge 120 ]] && die "App failed to start. Run: docker compose logs app"
done
echo; log "App is ready."

# ── 健康汇总 ──────────────────────────────────────────────────────────────
echo
echo -e "  ${GREEN}✓ Deployment complete!${NC}"
echo
echo -e "  REST API    →  ${CYAN}http://localhost:3000${NC}"
echo -e "  MCP SSE     →  ${CYAN}http://localhost:3000/mcp${NC}"
echo -e "  Health      →  ${CYAN}http://localhost:3000/health${NC}"
echo
echo "  MCP client config (Claude Desktop / Cursor):"
echo '  ┌─────────────────────────────────────────────────────────┐'
echo '  │  {                                                       │'
echo '  │    "mcpServers": {                                       │'
echo '  │      "websearch": {                                      │'
echo '  │        "url": "http://<YOUR_SERVER_IP>:3000/mcp"        │'
echo '  │      }                                                   │'
echo '  │    }                                                     │'
echo '  │  }                                                       │'
echo '  └─────────────────────────────────────────────────────────┘'
echo
docker compose ps
