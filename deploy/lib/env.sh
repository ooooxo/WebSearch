#!/usr/bin/env bash
# .env 工具：读取 / 写入
# 新架构原则：setup-vps.sh 写入一次即正确，不再需要 repair 逻辑

# 加载 .env 到当前 shell（set -a 使变量自动 export）
load_env_file() {
    local env_file="${1:-${PROJECT_ROOT:-$(pwd)}/.env}"
    [[ -f "$env_file" ]] || return 0
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
}

# 写入 .env（所有复杂值用双引号包裹）
# 调用前需要设置好所有变量
write_env_file() {
    local env_file="${1:-${PROJECT_ROOT:-$(pwd)}/.env}"
    {
        printf '# WebSearch 配置 — %s\n\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        printf 'APP_PORT=%s\n'              "${APP_PORT:-18900}"
        printf 'USE_BUILTIN_REDIS=%s\n'      "${USE_BUILTIN_REDIS:-false}"
        printf 'USE_BUILTIN_POSTGRES=%s\n'   "${USE_BUILTIN_POSTGRES:-false}"
        printf 'REDIS_CONNECTION="%s"\n'     "${REDIS_CONNECTION:-localhost:6379,abortConnect=false}"
        printf 'POSTGRES_CONNECTION="%s"\n'  "${POSTGRES_CONNECTION}"
        printf 'POSTGRES_PASSWORD="%s"\n'    "${POSTGRES_PASSWORD}"
        printf 'SEARXNG_SECRET_KEY="%s"\n'   "${SEARXNG_SECRET_KEY}"
        printf 'FIRECRAWL_API_KEY="%s"\n'    "${FIRECRAWL_API_KEY:-}"
        printf 'TAVILY_API_KEY="%s"\n'       "${TAVILY_API_KEY:-}"
        printf 'CACHE_SEARCH_TTL=%s\n'       "${CACHE_SEARCH_TTL:-7200}"
        printf 'CACHE_SCRAPE_TTL=%s\n'       "${CACHE_SCRAPE_TTL:-86400}"
        printf 'API_DOMAIN=%s\n'             "${API_DOMAIN:-}"
        printf 'CERTBOT_EMAIL=%s\n'          "${CERTBOT_EMAIL:-}"
        printf 'NGINX_SITE_NAME=%s\n'        "${NGINX_SITE_NAME:-websearch}"
    } > "$env_file"
    chmod 600 "$env_file"
    ok "已写入 ${env_file}"
}
