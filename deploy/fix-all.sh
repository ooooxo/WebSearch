#!/usr/bin/env bash
# WebSearch 一键修复（非交互，使用已有 .env）
# 用法: sudo bash fix.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/compose.sh"
source "$SCRIPT_DIR/lib/env.sh"
source "$SCRIPT_DIR/lib/api-ready.sh"

cd "$PROJECT_ROOT"

# ===========================
# 验证 .env 基本完整性
# ===========================
validate_env() {
    [[ -f .env ]] || { err ".env 不存在，请先运行: sudo bash install.sh"; exit 1; }
    /usr/bin/grep -q '^POSTGRES_CONNECTION=' .env || {
        err ".env 缺少 POSTGRES_CONNECTION，请重新运行: sudo bash install.sh"
        exit 1
    }
    /usr/bin/grep -q '^REDIS_CONNECTION=' .env || {
        warn ".env 缺少 REDIS_CONNECTION，将追加默认值"
        echo 'REDIS_CONNECTION="localhost:6379,abortConnect=false"' >> .env
    }
    ok ".env 校验通过"
}

# 旧 host.docker.internal 残留 → 替换成 localhost
fix_old_gateway() {
    if /usr/bin/grep -q 'host\.docker\.internal' .env 2>/dev/null; then
        python3 -c "
with open('.env') as f:
    c = f.read()
c = c.replace('host.docker.internal', 'localhost')
with open('.env', 'w') as f:
    f.write(c)
" && warn "已将 .env 中 host.docker.internal → localhost（旧配置兼容）"
    fi
}

# 显示当前连接配置（隐藏密码）
show_config() {
    info "当前连接配置:"
    while IFS= read -r line; do
        echo "  ${line//Password=*/Password=***}"
    done < <(/usr/bin/grep -E '^(USE_BUILTIN|REDIS_CONNECTION|POSTGRES_CONNECTION)' .env 2>/dev/null || true)
}

# Nginx 重载（如果已配置）
reload_nginx() {
    load_env_file .env
    command -v nginx >/dev/null 2>&1 || return 0
    [[ -z "${API_DOMAIN:-}" ]] && return 0
    local site="${NGINX_SITE_NAME:-websearch}"
    [[ -f "/etc/nginx/sites-enabled/${site}" ]] || return 0
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || return 0
    ok "Nginx 已重载"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 \
        "https://${API_DOMAIN}/health/live" 2>/dev/null || echo "000")"
    [[ "$code" == "200" ]] \
        && ok "公网 HTTPS ✓  https://${API_DOMAIN}/health/live" \
        || warn "公网探活 HTTP ${code}"
}

main() {
    require_root
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    WebSearch 一键修复（fix.sh）       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    ensure_docker
    ensure_curl

    step "[1/3] 校验 .env"
    validate_env
    fix_old_gateway
    show_config

    step "[2/3] 重建并启动"
    compose_up --build --force-recreate

    step "[3/3] 等待就绪"
    if wait_for_api_ready 120 3000; then
        reload_nginx
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║          修复完成！                   ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
        echo ""
        load_env_file .env 2>/dev/null || true
        echo "  本地: curl http://127.0.0.1:3000/health"
        [[ -n "${API_DOMAIN:-}" ]] && echo "  公网: curl https://${API_DOMAIN}/health"
        echo ""
        exit 0
    fi

    echo ""
    err "API 未就绪，见上方诊断。修复建议："
    echo "  1. 重新安装: sudo bash install.sh"
    echo "  2. 查看日志: docker compose logs app"
    exit 1
}

main "$@"
