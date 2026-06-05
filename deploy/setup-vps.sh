#!/usr/bin/env bash
# WebSearch — 真正一键部署：.env 向导 + Docker 全栈 + Nginx HTTPS
# 用法: sudo bash deploy/setup-vps.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"

cd "$PROJECT_ROOT"

is_placeholder_env() {
    [[ ! -f .env ]] && return 0
    grep -q 'change-me-to-a-strong-password' .env 2>/dev/null \
        || grep -q 'change-me-to-a-random-string' .env 2>/dev/null \
        || grep -q 'api.yourdomain.com' .env 2>/dev/null
}

load_env() {
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
}

deploy_docker() {
    load_env

    step "启动 Docker 服务"

    if [[ "${USE_BUILTIN_REDIS:-true}" == "true" ]]; then
        info "Redis: 使用本项目内置容器"
    else
        info "Redis: 复用外部 → ${REDIS_CONNECTION}"
    fi

    if [[ "${USE_BUILTIN_POSTGRES:-true}" == "true" ]]; then
        info "PostgreSQL: 使用本项目内置容器"
    else
        info "PostgreSQL: 复用外部"
    fi

    compose_up --build

    info "等待 API 就绪（最多 60 秒）..."
    for i in $(seq 1 30); do
        if curl -fsS http://127.0.0.1:5080/health >/dev/null 2>&1; then
            ok "API 健康检查通过: http://127.0.0.1:5080/health"
            return 0
        fi
        sleep 2
    done

    warn "API 暂未响应，查看日志:"
    echo "  docker compose -f docker-compose.prod.yml logs -f api"
}

deploy_nginx() {
    if [[ "${SKIP_NGINX:-}" == "1" ]]; then
        warn "SKIP_NGINX=1，跳过 Nginx。"
        return 0
    fi

    load_env

    export NGINX_DOMAIN="${API_DOMAIN:-}"
    export CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
    export NGINX_BACKEND_HOST="${NGINX_BACKEND_HOST:-127.0.0.1}"
    export NGINX_BACKEND_PORT="${NGINX_BACKEND_PORT:-5080}"
    export NGINX_SITE_NAME="${NGINX_SITE_NAME:-websearch}"
    export ENABLE_HTTPS="${ENABLE_HTTPS:-y}"
    export DEPLOY_FROM_SETUP=1

    if [[ -z "${NGINX_DOMAIN}" ]]; then
        warn ".env 中无 API_DOMAIN，跳过 Nginx。"
        return 0
    fi

    step "配置 Nginx 反代 + HTTPS"

    # 已有域名则走非交互；setup-nginx 仍会检测后端
    bash "$SCRIPT_DIR/nginx/setup-nginx.sh"
}

print_summary() {
    load_env 2>/dev/null || true

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           部署完成！                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""

    if [[ -n "${API_DOMAIN:-}" ]]; then
        echo "  API 地址:   https://${API_DOMAIN}"
        echo "  健康检查:   curl https://${API_DOMAIN}/health"
        echo "  搜索测试:   curl -X POST https://${API_DOMAIN}/search -H 'Content-Type: application/json' -d '{\"query\":\"test\"}'"
    else
        echo "  本地 API:   curl http://127.0.0.1:5080/health"
    fi

    echo ""
    echo "  查看日志:   docker compose -f docker-compose.prod.yml logs -f api"
    echo "  重新部署:   sudo bash install.sh"
    echo "  卸载:       sudo bash uninstall.sh"
    echo ""
}

main() {
    require_root
    banner

    info "项目目录: ${PROJECT_ROOT}"
    ensure_docker
    ensure_curl

    # ── .env 配置 ──
    if [[ -f .env ]] && ! is_placeholder_env; then
        if prompt_yn "检测到已有 .env，是否重新配置?" "n"; then
            # shellcheck source=deploy/configure-env.sh
            source "$SCRIPT_DIR/configure-env.sh"
            run_configure_env_interactive
        else
            ok "使用现有 .env"
        fi
    else
        # shellcheck source=deploy/configure-env.sh
        source "$SCRIPT_DIR/configure-env.sh"
        run_configure_env_interactive
    fi

    # ── Docker ──
    deploy_docker

    # ── Nginx ──
    deploy_nginx

    print_summary
}

main "$@"
