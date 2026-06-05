#!/usr/bin/env bash
# 等待 API /health 就绪（1 秒轮询，超时后自动诊断）

wait_for_api_ready() {
    local max_wait="${1:-120}"   # 最多等待秒数
    local port="${2:-5080}"
    local elapsed=0

    info "等待 API 就绪（最多 ${max_wait}s）..."

    while (( elapsed < max_wait )); do
        local live ready
        live="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 1 \
            "http://127.0.0.1:${port}/health/live" 2>/dev/null || echo "000")"
        ready="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 1 \
            "http://127.0.0.1:${port}/health" 2>/dev/null || echo "000")"

        if [[ "$ready" == "200" ]]; then
            ok "API 就绪 ✓  /health → 200  (${elapsed}s)"
            return 0
        fi

        # 每 5 秒打一次状态
        if (( elapsed % 5 == 0 )); then
            local status
            if [[ "$live" == "000" ]]; then
                status="进程未启动"
            elif [[ "$live" == "200" && "$ready" == "503" ]]; then
                status="进程已起，Redis/PG 健康检查失败"
            elif [[ "$live" == "200" ]]; then
                status="进程已起，/health → ${ready}"
            else
                status="live=${live} ready=${ready}"
            fi
            printf "\r  [%3ds] %s                    " "$elapsed" "$status"
        fi

        sleep 1
        elapsed=$(( elapsed + 1 ))
    done

    echo ""
    echo ""
    warn "等待超时（${max_wait}s）。自动诊断："
    _diagnose_api "$port"
    return 1
}

_diagnose_api() {
    local port="${1:-5080}"

    echo ""
    info "=== 容器状态 ==="
    compose_ps 2>/dev/null || docker compose -f docker-compose.prod.yml ps 2>/dev/null || true

    echo ""
    info "=== API 日志（最后 60 行）==="
    compose_logs api --tail 60 2>/dev/null \
        || docker compose -f docker-compose.prod.yml logs api --tail 60 2>/dev/null \
        || true

    echo ""
    info "=== /health 响应 ==="
    curl -s --connect-timeout 3 "http://127.0.0.1:${port}/health" 2>/dev/null \
        | python3 -m json.tool 2>/dev/null \
        || echo "(无响应)"

    echo ""
    info "=== 容器内实际连接串 ==="
    local api_id
    api_id="$(docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null \
        | awk -F'\t' '/websearch-api/' | awk '{print $1}' | head -1)"
    if [[ -n "$api_id" ]]; then
        echo "  ConnectionStrings__Postgres: $(docker exec "$api_id" printenv ConnectionStrings__Postgres 2>/dev/null | sed 's/Password=.*/Password=***/')"
        echo "  Redis__Connection:           $(docker exec "$api_id" printenv Redis__Connection 2>/dev/null)"
        echo "  SearXng__BaseUrl:            $(docker exec "$api_id" printenv SearXng__BaseUrl 2>/dev/null)"
    else
        echo "  API 容器未运行"
    fi

    echo ""
    info "=== 常见原因与修复 ==="
    echo "  1. PG 还没建库 → docker exec -it game-postgres psql -U postgres"
    echo "       CREATE DATABASE websearch;"
    echo "       CREATE USER websearch WITH PASSWORD '你的密码';"
    echo "       GRANT ALL PRIVILEGES ON DATABASE websearch TO websearch;"
    echo ""
    echo "  2. .env 密码错误 → /usr/bin/grep POSTGRES_CONNECTION .env"
    echo ""
    echo "  3. Redis 有密码 → 在 .env 中改为:"
    echo "       REDIS_CONNECTION=localhost:6379,password=你的密码,abortConnect=false"
    echo ""
    echo "  修复后重跑: sudo bash fix.sh"
}
