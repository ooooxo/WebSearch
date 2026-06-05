#!/usr/bin/env bash
# WebSearch 一键安装
# 用法: sudo bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/compose.sh"
source "$SCRIPT_DIR/lib/env.sh"
source "$SCRIPT_DIR/lib/api-ready.sh"

cd "$PROJECT_ROOT"

# ===========================
# 全局配置变量（由 configure_* 函数填充）
# ===========================
USE_BUILTIN_REDIS=""
USE_BUILTIN_POSTGRES=""
REDIS_CONNECTION=""
POSTGRES_CONNECTION=""
POSTGRES_PASSWORD=""
SEARXNG_SECRET_KEY=""
API_DOMAIN=""
CERTBOT_EMAIL=""
NGINX_SITE_NAME="websearch"
CACHE_SEARCH_TTL="7200"
CACHE_SCRAPE_TTL="86400"
FIRECRAWL_API_KEY=""
JINA_API_KEY=""

# ===========================
# Redis 连接测试（通过临时 Docker 容器）
# ===========================
test_redis_conn() {
    local conn="$1"
    # 解析连接串: host:port[,password=xxx][,abortConnect=false]
    local host port password=""
    host="${conn%%:*}"
    local rest="${conn#*:}"
    port="${rest%%,*}"
    if echo "$rest" | /usr/bin/grep -q 'password='; then
        password="$(echo "$rest" | /usr/bin/grep -oP '(?<=password=)[^,]+')"
    fi
    local args=(-h "$host" -p "$port")
    [[ -n "$password" ]] && args+=(-a "$password" --no-auth-warning)
    docker run --rm --network host redis:7-alpine redis-cli "${args[@]}" PING 2>/dev/null \
        | /usr/bin/grep -qi PONG
}

# ===========================
# Postgres 操作：通过 Docker 容器名
# ===========================
pg_exec_docker() {
    # pg_exec_docker CONTAINER SUPERUSER SUPERPASS SQL [DB]
    local container="$1" superuser="$2" superpass="$3" sql="$4" db="${5:-postgres}"
    if [[ -n "$superpass" ]]; then
        docker exec -e PGPASSWORD="$superpass" "$container" \
            psql -U "$superuser" -d "$db" -c "$sql" 2>&1
    else
        docker exec "$container" psql -U "$superuser" -d "$db" -c "$sql" 2>&1
    fi
}

# Postgres 操作：通过 psql 命令行（宿主机）
pg_exec_psql() {
    local host="$1" port="$2" superuser="$3" superpass="$4" sql="$5" db="${6:-postgres}"
    PGPASSWORD="$superpass" psql -h "$host" -p "$port" -U "$superuser" -d "$db" -c "$sql" 2>&1
}

# 在外部 Postgres 中创建 websearch 数据库、用户并授权
setup_external_pg() {
    local container="$1" superuser="$2" superpass="$3"
    local db="websearch" ws_user="websearch" ws_pass="$POSTGRES_PASSWORD"

    info "在 Postgres 中创建数据库 '${db}' 和用户 '${ws_user}'..."

    if [[ -n "$container" ]]; then
        pg_exec_docker "$container" "$superuser" "$superpass" "CREATE DATABASE ${db};" \
            || warn "数据库 ${db} 可能已存在，继续..."
        pg_exec_docker "$container" "$superuser" "$superpass" "DROP USER IF EXISTS ${ws_user};"
        pg_exec_docker "$container" "$superuser" "$superpass" "CREATE USER ${ws_user} WITH PASSWORD '${ws_pass}';"
        pg_exec_docker "$container" "$superuser" "$superpass" "GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${ws_user};"
        pg_exec_docker "$container" "$superuser" "$superpass" "GRANT ALL ON SCHEMA public TO ${ws_user};" "$db" \
            2>/dev/null || true
    else
        command -v psql >/dev/null || { err "未安装 psql，无法自动建库，请手动操作"; return 1; }
        pg_exec_psql localhost 5432 "$superuser" "$superpass" "CREATE DATABASE ${db};" \
            || warn "数据库 ${db} 可能已存在"
        pg_exec_psql localhost 5432 "$superuser" "$superpass" "DROP USER IF EXISTS ${ws_user};"
        pg_exec_psql localhost 5432 "$superuser" "$superpass" "CREATE USER ${ws_user} WITH PASSWORD '${ws_pass}';"
        pg_exec_psql localhost 5432 "$superuser" "$superpass" "GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${ws_user};"
        pg_exec_psql localhost 5432 "$superuser" "$superpass" "GRANT ALL ON SCHEMA public TO ${ws_user};" websearch \
            2>/dev/null || true
    fi
    ok "Postgres websearch 数据库和用户就绪"
}

# ===========================
# [1/5] Redis 配置
# ===========================
configure_redis() {
    step "[1/5] Redis 配置"
    echo "  API 使用 host 网络，通过 localhost:6379 访问 Redis。"
    echo ""

    local container line
    line="$(container_on_port 6379 || true)"

    if port_in_use 6379 || [[ -n "$line" ]]; then
        if [[ -n "$line" ]]; then
            info "检测到 Docker 容器占用端口 6379:"
            echo "  $line"
        else
            info "检测到宿主机进程占用端口 6379"
        fi
        echo ""
        warn "端口已被占用，将连接此 Redis（无法新建内置容器）"
        USE_BUILTIN_REDIS=false

        local redis_pass=""
        read -r -s -p "  Redis 密码（无密码直接回车）: " redis_pass; echo ""

        if [[ -z "$redis_pass" ]]; then
            REDIS_CONNECTION="localhost:6379,abortConnect=false"
        else
            REDIS_CONNECTION="localhost:6379,password=${redis_pass},abortConnect=false"
        fi

        info "测试 Redis 连接..."
        if test_redis_conn "$REDIS_CONNECTION"; then
            ok "Redis 连接测试通过 ✓"
        else
            err "Redis 连接失败！请检查密码是否正确"
            err "连接串: ${REDIS_CONNECTION}"
            exit 1
        fi
        return
    fi

    info "端口 6379 空闲。"
    if prompt_yn "  使用外部 Redis（非本项目容器）?" "n"; then
        USE_BUILTIN_REDIS=false
        local redis_host redis_port redis_pass=""
        prompt redis_host "  Redis 主机" "localhost"
        prompt redis_port "  Redis 端口" "6379"
        read -r -s -p "  Redis 密码（无密码直接回车）: " redis_pass; echo ""
        if [[ -z "$redis_pass" ]]; then
            REDIS_CONNECTION="${redis_host}:${redis_port},abortConnect=false"
        else
            REDIS_CONNECTION="${redis_host}:${redis_port},password=${redis_pass},abortConnect=false"
        fi
        info "测试 Redis 连接..."
        test_redis_conn "$REDIS_CONNECTION" && ok "Redis 连接测试通过 ✓" || {
            err "Redis 连接失败！"; exit 1
        }
    else
        USE_BUILTIN_REDIS=true
        REDIS_CONNECTION="localhost:6379,abortConnect=false"
        ok "将新建内置 Redis 容器（127.0.0.1:6379）"
    fi
}

# ===========================
# [2/5] PostgreSQL 配置
# ===========================
configure_postgres() {
    step "[2/5] PostgreSQL 配置"
    echo "  API 使用 host 网络，通过 localhost:5432 访问 PostgreSQL。"
    echo ""

    local container line
    line="$(container_on_port 5432 || true)"

    if port_in_use 5432 || [[ -n "$line" ]]; then
        if [[ -n "$line" ]]; then
            info "检测到 Docker 容器占用端口 5432:"
            echo "  $line"
        else
            info "检测到宿主机进程占用端口 5432"
        fi
        echo ""
        warn "端口已被占用，将连接此 PostgreSQL（无法新建内置容器）"
        USE_BUILTIN_POSTGRES=false

        echo "  请输入 PostgreSQL 超级用户凭据（用于自动创建 websearch 数据库和用户）:"
        local superuser superpass
        prompt superuser "  超级用户名" "postgres"
        read -r -s -p "  超级用户密码（无密码直接回车）: " superpass; echo ""

        # 生成 websearch 用户的随机密码
        POSTGRES_PASSWORD="$(generate_secret)"

        # 获取容器名（如果有）
        local container_name
        container_name="$(container_name_on_port 5432 || true)"

        # 创建 DB 和用户
        setup_external_pg "$container_name" "$superuser" "$superpass"

        POSTGRES_CONNECTION="Host=localhost;Port=5432;Database=websearch;Username=websearch;Password=${POSTGRES_PASSWORD}"
        ok "PostgreSQL 配置完成"
        return
    fi

    info "端口 5432 空闲。"
    if prompt_yn "  使用外部 PostgreSQL（非本项目容器）?" "n"; then
        USE_BUILTIN_POSTGRES=false
        local pg_host pg_port pg_database pg_user superuser superpass
        prompt pg_host     "  PostgreSQL 主机" "localhost"
        prompt pg_port     "  端口"            "5432"
        prompt pg_database "  数据库名"        "websearch"
        prompt pg_user     "  用户名"          "websearch"
        read -r -s -p "  密码: " POSTGRES_PASSWORD; echo ""
        [[ -z "$POSTGRES_PASSWORD" ]] && { err "密码不能为空"; exit 1; }
        POSTGRES_CONNECTION="Host=${pg_host};Port=${pg_port};Database=${pg_database};Username=${pg_user};Password=${POSTGRES_PASSWORD}"
    else
        USE_BUILTIN_POSTGRES=true
        POSTGRES_PASSWORD="$(generate_secret)"
        POSTGRES_CONNECTION="Host=localhost;Port=5432;Database=websearch;Username=websearch;Password=${POSTGRES_PASSWORD}"
        ok "将新建内置 PostgreSQL 容器（127.0.0.1:5432）"
    fi
}

# ===========================
# [3/5] 其他密钥与可选配置
# ===========================
configure_misc() {
    step "[3/5] 密钥与可选配置"

    read -r -s -p "  SearXNG 密钥（回车自动生成）: " SEARXNG_SECRET_KEY; echo ""
    [[ -z "$SEARXNG_SECRET_KEY" ]] && SEARXNG_SECRET_KEY="$(generate_secret)"
    ok "SearXNG 密钥已设置"

    echo ""
    read -r -p "  Firecrawl API Key（可选，回车跳过）: " FIRECRAWL_API_KEY
    read -r -p "  Jina API Key（可选，回车跳过）: "      JINA_API_KEY
    prompt CACHE_SEARCH_TTL "  搜索缓存 TTL（秒）" "7200"
    prompt CACHE_SCRAPE_TTL "  抓取缓存 TTL（秒）" "86400"
}

# ===========================
# [4/5] 域名与 HTTPS
# ===========================
configure_domain() {
    step "[4/5] 域名与 HTTPS"
    echo "  请确保域名 A 记录已指向本 VPS IP。"
    echo ""

    prompt API_DOMAIN "  API 域名（如 api.example.com）" ""
    [[ -z "$API_DOMAIN" ]] && { err "域名不能为空"; exit 1; }

    if [[ -f "/etc/letsencrypt/live/${API_DOMAIN}/fullchain.pem" ]]; then
        ok "检测到已有证书，将直接复用，无需填邮箱"
        CERTBOT_EMAIL=""
    else
        prompt CERTBOT_EMAIL "  Certbot 邮箱（HTTPS 证书通知）" ""
        [[ -z "$CERTBOT_EMAIL" ]] && warn "未填邮箱，证书续签通知将发送到默认地址"
    fi
}

# ===========================
# [5/5] 确认并写入
# ===========================
confirm_and_write() {
    step "[5/5] 确认配置"
    echo ""
    echo "  Redis:        $( [[ "$USE_BUILTIN_REDIS" == "true" ]] && echo '新建内置容器' || echo "外部 → ${REDIS_CONNECTION//password=*/password=***}" )"
    echo "  PostgreSQL:   $( [[ "$USE_BUILTIN_POSTGRES" == "true" ]] && echo '新建内置容器' || echo 'localhost:5432（已创建 websearch 数据库和用户）' )"
    echo "  SearXNG 密钥: (已设置)"
    echo "  搜索缓存 TTL: ${CACHE_SEARCH_TTL}s"
    echo "  域名:         https://${API_DOMAIN}"
    [[ -f "/etc/letsencrypt/live/${API_DOMAIN}/fullchain.pem" ]] \
        && echo "  HTTPS 证书:   复用已有" \
        || echo "  Certbot 邮箱: ${CERTBOT_EMAIL:-（未设置）}"
    echo ""

    prompt_yn "  确认写入 .env 并开始部署?" "y" || { info "已取消"; exit 0; }
}

sync_searxng_key() {
    local settings="$PROJECT_ROOT/deploy/searxng/settings.yml"
    [[ -f "$settings" ]] || return 0
    /usr/bin/grep -q 'secret_key:' "$settings" || return 0
    sed -i "s|secret_key:.*|secret_key: \"${SEARXNG_SECRET_KEY}\"|" "$settings"
    ok "已同步 SearXNG secret_key"
}

# ===========================
# 清理旧环境
# ===========================
cleanup_old_env() {
    step "清理旧环境"
    info "停止并移除旧容器..."
    compose_down --volumes 2>/dev/null || docker compose -f docker-compose.prod.yml down --volumes 2>/dev/null || true
    info "清理旧镜像..."
    docker image rm websearch-api:latest websearch-crawl4ai:latest 2>/dev/null || true
    rm -f docker-compose.prod.override.yml 2>/dev/null || true
    ok "旧环境清理完成（.env 保留，外部 Redis/PostgreSQL 未动）"
}

# ===========================
# Docker 构建与启动
# ===========================
deploy_docker() {
    step "构建并启动服务"
    info "API 使用 host 网络 → localhost 直接访问所有服务"
    compose_up --build --force-recreate
}

# ===========================
# Nginx 配置
# ===========================
deploy_nginx() {
    [[ "${SKIP_NGINX:-}" == "1" ]] && { warn "SKIP_NGINX=1，跳过 Nginx"; return 0; }
    [[ -z "${API_DOMAIN:-}" ]]     && { warn "未配置 API_DOMAIN，跳过 Nginx"; return 0; }

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

# ===========================
# 总结
# ===========================
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         部署完成！                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    if [[ -n "${API_DOMAIN:-}" ]]; then
        echo "  API:      https://${API_DOMAIN}"
        echo "  健康检查: curl https://${API_DOMAIN}/health"
    fi
    echo "  本地检查: curl http://127.0.0.1:5080/health"
    echo ""
    echo "  一键修复: sudo bash fix.sh"
    echo "  看日志:   docker compose -f docker-compose.prod.yml logs -f api"
    echo ""
}

# ===========================
# 主流程
# ===========================
main() {
    require_root
    banner
    ensure_docker
    ensure_curl

    # 若已有有效 .env，询问是否重用
    if [[ -f .env ]] && /usr/bin/grep -q '^POSTGRES_CONNECTION=' .env 2>/dev/null; then
        step "检测到已有 .env"
        info "若要修改 Redis/Postgres 密码或域名，选 n 进入重新配置"
        if prompt_yn "  沿用现有 .env 直接重装?" "y"; then
            load_env_file .env
            # 从 .env 补齐全局变量
            SEARXNG_SECRET_KEY="${SEARXNG_SECRET_KEY:-}"
            API_DOMAIN="${API_DOMAIN:-}"
            CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
            cleanup_old_env
            deploy_docker
            wait_for_api_ready 120 5080 || warn "API 暂未就绪，见上方诊断"
            deploy_nginx
            print_summary
            return
        fi
    fi

    # 全新配置流程
    configure_redis
    configure_postgres
    configure_misc
    configure_domain
    confirm_and_write

    write_env_file "$PROJECT_ROOT/.env"
    sync_searxng_key
    cleanup_old_env
    deploy_docker

    wait_for_api_ready 120 5080 || warn "API 暂未就绪，见上方诊断"
    deploy_nginx
    print_summary
}

main "$@"
