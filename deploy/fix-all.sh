#!/usr/bin/env bash
# WebSearch 傻瓜式一键修复（不删数据、不重装 Nginx 证书）
# 修复内容：
#   1. .env 引号修复（双引号，兼容 bash + Docker）
#   2. 外部 Docker 容器网络自动检测（解决 host.docker.internal 无法访问 127.0.0.1 问题）
#   3. 连接串更新（用容器名替换 host.docker.internal）
#   4. 生成 compose 网络 override
#   5. docker compose up --build --force-recreate
#   6. 健康检查 + 诊断输出
#   7. Nginx 重载
#
# 用法: sudo bash fix.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/detect-infra.sh
source "$SCRIPT_DIR/lib/detect-infra.sh"
# shellcheck source=deploy/lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"
# shellcheck source=deploy/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
# shellcheck source=deploy/lib/container-network.sh
source "$SCRIPT_DIR/lib/container-network.sh"
# shellcheck source=deploy/lib/api-ready.sh
source "$SCRIPT_DIR/lib/api-ready.sh"
# shellcheck source=deploy/lib/nginx-cert.sh
source "$SCRIPT_DIR/lib/nginx-cert.sh"

cd "$PROJECT_ROOT"

# ---------- helpers ----------

show_env_summary() {
    info "当前 .env 连接配置（密码已隐藏）:"
    while IFS= read -r line; do
        if [[ "$line" == *Password=* ]]; then
            echo "  ${line%%Password=*}Password=***"
        else
            echo "  ${line}"
        fi
    done < <(grep_safe -E '^(USE_BUILTIN_REDIS|USE_BUILTIN_POSTGRES|REDIS_CONNECTION|POSTGRES_CONNECTION)=' .env 2>/dev/null || true)
}

verify_container_env() {
    local api_id
    api_id="$(compose_cmd ps -q api 2>/dev/null | head -1 || true)"
    if [[ -z "$api_id" ]]; then
        warn "API 容器未运行，跳过容器内环境检查"
        return 0
    fi

    local pg redis
    pg="$(docker exec "$api_id" printenv ConnectionStrings__Postgres 2>/dev/null || echo "<未设置>")"
    redis="$(docker exec "$api_id" printenv Redis__Connection 2>/dev/null || echo "<未设置>")"

    local pg_display="${pg//Password=*/Password=***}"
    info "容器内 ConnectionStrings__Postgres: ${pg_display}"
    info "容器内 Redis__Connection:            ${redis}"

    if [[ "$pg" == \'* ]] || [[ "$pg" == \"* ]]; then
        err "PostgreSQL 连接串含有多余引号！Docker 没有正确展开 .env 变量。"
        return 1
    fi
    if [[ -z "$pg" ]] || [[ "$pg" == "<未设置>" ]]; then
        err "ConnectionStrings__Postgres 为空，数据库迁移会失败。"
        return 1
    fi

    ok "容器内连接串格式正常"
}

reload_nginx_if_running() {
    command -v nginx >/dev/null 2>&1 || return 0
    load_env 2>/dev/null || true
    [[ -z "${API_DOMAIN:-}" ]] && return 0

    local site="${NGINX_SITE_NAME:-websearch}"
    [[ -f "/etc/nginx/sites-enabled/${site}" ]] || return 0

    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null || true
        ok "Nginx 已重载"
    fi

    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "https://${API_DOMAIN}/health/live" 2>/dev/null || echo "000")"
    if [[ "$code" == "200" ]]; then
        ok "公网 HTTPS 正常: https://${API_DOMAIN}/health/live"
    else
        warn "公网探活 HTTP ${code} — 请检查 Nginx 配置或等 API 完全就绪后再试"
    fi
}

load_env() {
    repair_env_file "$PROJECT_ROOT/.env"
}

# ---------- main ----------

main() {
    require_root

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    WebSearch 一键修复（fix.sh）       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    info "项目目录: ${PROJECT_ROOT}"

    if [[ ! -f .env ]]; then
        err "未找到 .env，请先运行: sudo bash install.sh"
        exit 1
    fi

    ensure_docker
    ensure_curl

    # ── Step 1：修复 .env 引号与缺失项 ────────────────────
    step "[1/6] 修复 .env"
    repair_env_file "$PROJECT_ROOT/.env"
    load_env
    show_env_summary

    # ── Step 2：同步 SearXNG 密钥 ─────────────────────────
    step "[2/6] 同步 SearXNG 密钥"
    if [[ -f deploy/searxng/settings.yml ]] && [[ -n "${SEARXNG_SECRET_KEY:-}" ]]; then
        if grep_safe -q 'secret_key:' deploy/searxng/settings.yml; then
            sed -i "s|secret_key:.*|secret_key: \"${SEARXNG_SECRET_KEY}\"|" deploy/searxng/settings.yml
            ok "SearXNG settings.yml 已同步"
        fi
    else
        info "跳过（settings.yml 不存在或 SEARXNG_SECRET_KEY 未设置）"
    fi

    # ── Step 3：外部容器网络检测（解决 127.0.0.1 无法访问问题）──
    step "[3/6] 检测外部容器网络"
    echo "  说明: 若 game-redis / game-postgres 绑定在宿主机 127.0.0.1，"
    echo "        host.docker.internal 在 Linux 上指向 Docker bridge 网关，"
    echo "        与 127.0.0.1 不同，导致 API 容器无法访问。"
    echo "        修复：让 API 加入 game 容器所在网络，改用容器名直连。"
    echo ""
    setup_container_networking
    # 重新读取 .env（setup_container_networking 可能已更新连接串）
    load_env
    show_env_summary

    # ── Step 4：重建容器 ───────────────────────────────────
    step "[4/6] 重建并启动 Docker 服务"
    if [[ "${USE_BUILTIN_REDIS:-true}" == "true" ]]; then
        info "Redis:      内置容器"
    else
        info "Redis:      外部 → ${REDIS_CONNECTION}"
    fi
    if [[ "${USE_BUILTIN_POSTGRES:-true}" == "true" ]]; then
        info "PostgreSQL: 内置容器"
    else
        info "PostgreSQL: 外部"
    fi

    compose_up --build --force-recreate

    # ── Step 5：等待就绪 ───────────────────────────────────
    step "[5/6] 等待 API 就绪"
    sleep 3
    verify_container_env || warn "容器环境检查有异常，继续等待健康检查..."
    echo ""

    if wait_for_api_ready 60 2; then
        step "[6/6] 重载 Nginx"
        reload_nginx_if_running

        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║            修复完成！                 ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo "  本地健康: curl http://127.0.0.1:5080/health"
        if [[ -n "${API_DOMAIN:-}" ]]; then
            echo "  公网健康: curl https://${API_DOMAIN}/health"
        fi
        echo ""
        exit 0
    fi

    echo ""
    err "API 仍未就绪。请查看上方日志定位原因。"
    echo ""
    echo "  快速排查命令:"
    echo "    docker compose -f docker-compose.prod.yml ps"
    echo "    docker compose -f docker-compose.prod.yml logs api --tail 80"
    echo "    docker compose -f docker-compose.prod.yml exec api printenv ConnectionStrings__Postgres"
    echo "    /usr/bin/grep -E 'POSTGRES_CONNECTION|REDIS_CONNECTION' .env"
    echo ""
    exit 1
}

main "$@"
