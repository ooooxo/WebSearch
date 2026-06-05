#!/usr/bin/env bash
# 等待 API /health 就绪，并在超时时输出诊断信息

wait_for_api_ready() {
    local max_attempts="${1:-45}"
    local sleep_seconds="${2:-2}"
    local attempt code

    info "等待 API 就绪（最多 $((max_attempts * sleep_seconds)) 秒）..."
    info "健康检查: /health/live（进程）→ /health（含 Redis + PostgreSQL）"

    for attempt in $(seq 1 "$max_attempts"); do
        local live_code ready_code
        live_code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:5080/health/live 2>/dev/null || echo "000")"
        ready_code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:5080/health 2>/dev/null || echo "000")"

        if [[ "$ready_code" == "200" ]]; then
            ok "API 就绪: http://127.0.0.1:5080/health"
            return 0
        fi

        case "$live_code" in
            200)
                if (( attempt % 5 == 1 )); then
                    warn "API 进程已启动 (/health/live=200)，但 /health=${ready_code}（Redis 或 PostgreSQL 未就绪）"
                fi
                ;;
            503|000)
                if [[ "$ready_code" == "503" ]] && (( attempt % 5 == 1 )); then
                    warn "API 已监听，但 /health 返回 503（Redis 或 PostgreSQL 连不上）"
                elif [[ "$live_code" == "000" && "$ready_code" == "000" ]]; then
                    if (( attempt % 5 == 1 )); then
                        info "API 尚未监听 5080（已等 $((attempt * sleep_seconds))s，可能在构建镜像或启动失败）..."
                    fi
                fi
                ;;
            *)
                if (( attempt % 5 == 1 )); then
                    warn "/health/live=${live_code} /health=${ready_code}"
                fi
                ;;
        esac

        sleep "$sleep_seconds"
    done

    diagnose_api_startup
    return 1
}

diagnose_api_startup() {
    step "API 未就绪 — 自动诊断"

    echo ""
    info "容器状态:"
    compose_ps 2>/dev/null || true

    echo ""
    info "API 最近日志:"
    compose_logs api --tail 50 2>/dev/null || true

    local live_code code health_file
    health_file="$(mktemp)"
    live_code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:5080/health/live 2>/dev/null || echo "000")"
    code="$(curl -s -o "$health_file" -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:5080/health 2>/dev/null || echo "000")"

    echo ""
    if [[ "$code" == "000" && "$live_code" == "000" ]]; then
        warn "127.0.0.1:5080 无响应 — API 容器可能未启动或仍在崩溃重启"
        echo "  常见原因: .env 单引号被 Docker 原样传入连接串、数据库连不上、镜像构建未完成"
        echo "  修复: bash deploy/repair-env.sh && docker compose -f docker-compose.prod.yml up -d --build api"
    elif [[ "$code" == "503" ]]; then
        warn "/health 返回 503 — 进程已启动，但 Redis 或 PostgreSQL 健康检查失败"
        echo "  响应体:"
        cat "$health_file" 2>/dev/null || true
        echo ""
        if [[ "${USE_BUILTIN_REDIS:-true}" == "false" ]]; then
            echo "  外部 Redis: ${REDIS_CONNECTION:-<未设置>}"
            echo "    → 确认 API 容器能访问 host.docker.internal:6379"
            echo "    → 若 Redis 有密码，连接串需写成: host:6379,password=xxx,abortConnect=false"
        fi
        if [[ "${USE_BUILTIN_POSTGRES:-true}" == "false" ]]; then
            echo "  外部 PostgreSQL: 见 .env 中 POSTGRES_CONNECTION"
            echo "    → 须已创建 database=websearch、user=websearch，且密码正确"
            echo "    → 在 game-postgres 中执行:"
            echo "        CREATE DATABASE websearch;"
            echo "        CREATE USER websearch WITH PASSWORD '你的密码';"
            echo "        GRANT ALL PRIVILEGES ON DATABASE websearch TO websearch;"
        fi
    else
        warn "/health 返回 HTTP ${code}"
        cat "$health_file" 2>/dev/null || true
    fi

    rm -f "$health_file"

    echo ""
    info "手动排查:"
    echo "  docker compose -f docker-compose.prod.yml ps"
    echo "  docker compose -f docker-compose.prod.yml logs -f api"
    echo "  curl -v http://127.0.0.1:5080/health/live"
    echo "  curl -v http://127.0.0.1:5080/health"
    echo "  docker compose -f docker-compose.prod.yml exec api printenv ConnectionStrings__Postgres"
    echo "  bash deploy/repair-env.sh   # 修复 .env 引号（双引号）"
}
