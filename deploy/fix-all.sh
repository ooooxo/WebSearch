#!/usr/bin/env bash
# WebSearch 一键修复
# 不删数据、不重装证书
# 用法: sudo bash fix.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/compose.sh"
source "$SCRIPT_DIR/lib/env.sh"
source "$SCRIPT_DIR/lib/api-ready.sh"
source "$SCRIPT_DIR/lib/nginx-cert.sh"

cd "$PROJECT_ROOT"

# ---------- helpers ----------

show_env() {
    info ".env 当前连接配置:"
    while IFS= read -r line; do
        echo "  ${line//Password=*/Password=***}"
    done < <(/usr/bin/grep -E '^(USE_BUILTIN|REDIS_CONNECTION|POSTGRES_CONNECTION)' .env 2>/dev/null || true)
}

fix_env_localhost() {
    # API 现在用 host 网络 — 把所有 host.docker.internal 替换成 localhost
    if /usr/bin/grep -q 'host\.docker\.internal' .env 2>/dev/null; then
        python3 -c "
with open('.env') as f:
    c = f.read()
c = c.replace('host.docker.internal', 'localhost')
with open('.env', 'w') as f:
    f.write(c)
print('[fixed] host.docker.internal → localhost')
"
    fi
    # 清理旧的 override 文件（已不再需要）
    rm -f docker-compose.prod.override.yml 2>/dev/null || true
}

reload_nginx() {
    command -v nginx >/dev/null 2>&1 || return 0
    repair_env_file "$PROJECT_ROOT/.env" 2>/dev/null || true
    [[ -z "${API_DOMAIN:-}" ]] && return 0
    local site="${NGINX_SITE_NAME:-websearch}"
    [[ -f "/etc/nginx/sites-enabled/${site}" ]] || return 0
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    ok "Nginx 已重载"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "https://${API_DOMAIN}/health/live" 2>/dev/null || echo "000")"
    [[ "$code" == "200" ]] && ok "公网 HTTPS ✓ https://${API_DOMAIN}/health/live" \
                           || warn "公网探活 HTTP ${code}"
}

# ---------- main ----------

main() {
    require_root

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    WebSearch 一键修复（fix.sh）       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    [[ -f .env ]] || { err "未找到 .env，请先运行: sudo bash install.sh"; exit 1; }

    ensure_docker
    ensure_curl

    step "[1/4] 修复 .env"
    repair_env_file "$PROJECT_ROOT/.env"
    fix_env_localhost
    repair_env_file "$PROJECT_ROOT/.env"   # 重新修复引号（localhost 替换后可能不需要）
    show_env

    step "[2/4] 同步 SearXNG 密钥"
    if [[ -f deploy/searxng/settings.yml ]] && [[ -n "${SEARXNG_SECRET_KEY:-}" ]]; then
        /usr/bin/grep -q 'secret_key:' deploy/searxng/settings.yml 2>/dev/null \
            && sed -i "s|secret_key:.*|secret_key: \"${SEARXNG_SECRET_KEY}\"|" deploy/searxng/settings.yml \
            && ok "已同步" || true
    fi

    step "[3/4] 重建并启动"
    info "API 使用 host 网络 → localhost:6379 / localhost:5432 直接访问宿主机服务"
    compose_up --build --force-recreate

    step "[4/4] 等待就绪"
    if wait_for_api_ready 120 5080; then
        reload_nginx
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║         修复完成！                    ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo "  curl http://127.0.0.1:5080/health"
        [[ -n "${API_DOMAIN:-}" ]] && echo "  curl https://${API_DOMAIN}/health"
        echo ""
        exit 0
    fi

    echo ""
    err "API 未就绪，见上方诊断。"
    exit 1
}

main "$@"
