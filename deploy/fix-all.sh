#!/usr/bin/env bash
# WebSearch 傻瓜式一键修复（不删数据、不重装 Nginx 证书）
# 修复 .env 引号 → 重建容器 → 健康检查 → 重载 Nginx
#
# 用法: sudo bash fix.sh
#   或: sudo bash deploy/fix-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"
# shellcheck source=deploy/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
# shellcheck source=deploy/lib/api-ready.sh
source "$SCRIPT_DIR/lib/api-ready.sh"
# shellcheck source=deploy/lib/nginx-cert.sh
source "$SCRIPT_DIR/lib/nginx-cert.sh"

cd "$PROJECT_ROOT"

mask_env_line() {
    local line="$1"
    if [[ "$line" == *Password=* ]]; then
        echo "${line%%Password=*}Password=***"
    else
        echo "$line"
    fi
}

show_env_connections() {
    info "当前 .env 连接配置:"
    while IFS= read -r line; do
        mask_env_line "$line"
    done < <(grep_safe -E '^(USE_BUILTIN_REDIS|USE_BUILTIN_POSTGRES|REDIS_CONNECTION|POSTGRES_CONNECTION)=' .env 2>/dev/null || true)
}

verify_container_connection_strings() {
    local api_id pg redis
    api_id="$(compose_cmd ps -q api 2>/dev/null | head -1 || true)"
    if [[ -z "$api_id" ]]; then
        warn "API 容器未运行，跳过容器内连接串检查"
        return 0
    fi

    pg="$(docker exec "$api_id" printenv ConnectionStrings__Postgres 2>/dev/null || true)"
    redis="$(docker exec "$api_id" printenv Redis__Connection 2>/dev/null || true)"

    info "容器内 ConnectionStrings__Postgres: ${pg//Password=*/Password=***}"
    info "容器内 Redis__Connection: ${redis}"

    if [[ "$pg" == \'* || "$pg" == \"* ]]; then
        err "PostgreSQL 连接串仍含引号，Docker 未正确读取 .env"
        return 1
    fi
    if [[ "$redis" == \'* || "$redis" == \"* ]]; then
        err "Redis 连接串仍含引号，Docker 未正确读取 .env"
        return 1
    fi
    if [[ -z "$pg" || "$pg" != Host=* ]]; then
        err "PostgreSQL 连接串异常（应以 Host= 开头）"
        return 1
    fi

    ok "容器内连接串格式正常"
}

reload_nginx_if_needed() {
    if ! command -v nginx >/dev/null 2>&1; then
        return 0
    fi

    load_env 2>/dev/null || true
    if [[ -z "${API_DOMAIN:-}" ]]; then
        return 0
    fi

    local site="${NGINX_SITE_NAME:-websearch}"
    if [[ ! -f "/etc/nginx/sites-enabled/${site}" ]]; then
        warn "未找到 Nginx 站点 ${site}，跳过 Nginx 重载"
        return 0
    fi

    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null || true
        ok "Nginx 已重载"
    fi

    if command -v curl >/dev/null 2>&1; then
        local code
        code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "https://${API_DOMAIN}/health/live" 2>/dev/null || echo "000")"
        if [[ "$code" == "200" ]]; then
            ok "公网 HTTPS 探活正常: https://${API_DOMAIN}/health/live"
        elif [[ "$code" == "502" ]]; then
            warn "公网仍返回 502 — 多为 API 未就绪或 Nginx upstream 配置问题"
        else
            warn "公网探活 HTTP ${code}: https://${API_DOMAIN}/health/live"
        fi
    fi
}

main() {
    require_root

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      WebSearch 一键修复（fix.sh）     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    info "项目目录: ${PROJECT_ROOT}"

    if [[ ! -f .env ]]; then
        err "未找到 .env，请先运行: sudo bash install.sh"
        exit 1
    fi

    ensure_docker
    ensure_curl

    step "[1/5] 修复 .env（引号 / 缺失项）"
    repair_env_file "$PROJECT_ROOT/.env"
    load_env
    show_env_connections

    step "[2/5] 同步 SearXNG 密钥"
    if [[ -f deploy/searxng/settings.yml ]] && [[ -n "${SEARXNG_SECRET_KEY:-}" ]]; then
        if grep_safe -q 'secret_key:' deploy/searxng/settings.yml; then
            sed -i "s|secret_key:.*|secret_key: \"${SEARXNG_SECRET_KEY}\"|" deploy/searxng/settings.yml
            ok "SearXNG settings.yml 已同步"
        fi
    fi

    step "[3/5] 重建并启动 Docker 服务"
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

    step "[4/5] 校验容器连接串"
    sleep 3
    verify_container_connection_strings || true

    step "[5/5] 等待 API 就绪"
    if wait_for_api_ready 60 2; then
        reload_nginx_if_needed
        echo ""
        ok "修复完成"
        echo ""
        echo "  本地: curl http://127.0.0.1:5080/health"
        if [[ -n "${API_DOMAIN:-}" ]]; then
            echo "  公网: curl https://${API_DOMAIN}/health"
        fi
        echo ""
        exit 0
    fi

    echo ""
    err "修复后 API 仍未就绪，请查看上方诊断日志"
    exit 1
}

main "$@"
