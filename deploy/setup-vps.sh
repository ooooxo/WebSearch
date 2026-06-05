#!/usr/bin/env bash
# WebSearch 傻瓜式一键重装：自动清理旧环境 → 配置 → Docker → Nginx
# 用法: sudo bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"
# shellcheck source=deploy/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
# shellcheck source=deploy/lib/lifecycle.sh
source "$SCRIPT_DIR/lib/lifecycle.sh"

cd "$PROJECT_ROOT"

is_placeholder_env() {
    [[ ! -f .env ]] && return 0
    grep -q 'change-me-to-a-strong-password' .env 2>/dev/null \
        || grep -q 'change-me-to-a-random-string' .env 2>/dev/null \
        || grep -q 'api.yourdomain.com' .env 2>/dev/null \
        || ! grep -q '^POSTGRES_CONNECTION=' .env 2>/dev/null
}

load_env() {
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
}

configure_for_install() {
    # shellcheck source=deploy/configure-env.sh
    source "$SCRIPT_DIR/configure-env.sh"

    if [[ -f .env ]] && ! is_placeholder_env; then
        repair_env_file "$PROJECT_ROOT/.env"
        step "配置"
        echo "  检测到已有 .env，将默认沿用现有配置。"
        echo "  若要改域名、密码、Redis/PG 等，选 n 进入重新配置。"
        echo ""
        if prompt_yn "沿用现有配置直接重装?" "y"; then
            load_env
            ok "沿用现有 .env"
            return 0
        fi
    fi

    run_configure_env_interactive
}

deploy_docker() {
    repair_env_file "$PROJECT_ROOT/.env"
    load_env

    step "构建并启动服务"

    if [[ "${USE_BUILTIN_REDIS:-true}" == "true" ]]; then
        info "Redis: 内置容器"
    else
        info "Redis: 外部 → ${REDIS_CONNECTION}"
    fi

    if [[ "${USE_BUILTIN_POSTGRES:-true}" == "true" ]]; then
        info "PostgreSQL: 内置容器"
    else
        info "PostgreSQL: 外部"
    fi

    compose_up --build --force-recreate

    info "等待 API 就绪（最多 90 秒）..."
    for i in $(seq 1 45); do
        if curl -fsS http://127.0.0.1:5080/health >/dev/null 2>&1; then
            ok "API 就绪: http://127.0.0.1:5080/health"
            return 0
        fi
        sleep 2
    done

    warn "API 暂未响应，请查看日志:"
    echo "  docker compose -f docker-compose.prod.yml logs -f api"
}

deploy_nginx() {
    if [[ "${SKIP_NGINX:-}" == "1" ]]; then
        warn "SKIP_NGINX=1，跳过 Nginx。"
        return 0
    fi

    load_env

    if [[ -z "${API_DOMAIN:-}" ]]; then
        warn "未配置 API_DOMAIN，跳过 Nginx。"
        return 0
    fi

    export NGINX_DOMAIN="${API_DOMAIN}"
    export CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
    export NGINX_BACKEND_HOST="127.0.0.1"
    export NGINX_BACKEND_PORT="5080"
    export NGINX_SITE_NAME="${NGINX_SITE_NAME:-websearch}"
    export ENABLE_HTTPS="y"
    export DEPLOY_FROM_SETUP=1

    step "配置 Nginx + HTTPS"
    bash "$SCRIPT_DIR/nginx/setup-nginx.sh"
}

print_summary() {
    load_env 2>/dev/null || true

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         部署完成，可以使用了         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""

    if [[ -n "${API_DOMAIN:-}" ]]; then
        echo "  API:      https://${API_DOMAIN}"
        echo "  健康检查: curl https://${API_DOMAIN}/health"
    else
        echo "  本地 API: curl http://127.0.0.1:5080/health"
    fi

    echo ""
    echo "  重装:     sudo bash install.sh"
    echo "  仅卸载:   sudo bash uninstall.sh"
    echo "  看日志:   docker compose -f docker-compose.prod.yml logs -f api"
    echo ""
}

main() {
    require_root
    banner

    info "项目目录: ${PROJECT_ROOT}"
    ensure_docker
    ensure_curl

    # 每次安装前先清理旧环境（无需确认）
    cleanup_before_install

    configure_for_install
    deploy_docker
    deploy_nginx
    print_summary
}

main "$@"
