#!/usr/bin/env bash
# Docker Compose 封装：读取 .env 决定是否启用内置 Redis/Postgres profile

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"

_compose_bin() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        err "未找到 docker compose 或 docker-compose"; return 1
    fi
}

# 从 .env 读取 USE_BUILTIN_* 并附加 profile 参数
_compose_profiles() {
    local env_file="${PROJECT_ROOT:-$(pwd)}/.env"
    local use_redis use_postgres
    use_redis="$(  /usr/bin/grep -E '^USE_BUILTIN_REDIS='    "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' || echo true)"
    use_postgres="$(/usr/bin/grep -E '^USE_BUILTIN_POSTGRES=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' || echo true)"
    local profiles=()
    [[ "$use_redis"    == "true" ]] && profiles+=(--profile builtin-redis)
    [[ "$use_postgres" == "true" ]] && profiles+=(--profile builtin-postgres)
    echo "${profiles[*]}"
}

compose_cmd() {
    [[ $# -lt 1 ]] && { err "compose_cmd: 缺少子命令"; return 1; }
    local root="${PROJECT_ROOT:-$(pwd)}"
    local compose_bin file_path
    compose_bin="$(_compose_bin)" || return 1
    file_path="${root}/${COMPOSE_FILE}"
    [[ -f "$file_path" ]] || { err "未找到 Compose 文件: ${file_path}"; return 1; }

    local profiles
    profiles="$(_compose_profiles)"
    
    info "Compose: ${compose_bin} -f ${COMPOSE_FILE} ${profiles} $*"
    # shellcheck disable=SC2086
    ${compose_bin} -f "$file_path" ${profiles} "$@"
}

compose_up()   { compose_cmd up -d "$@"; }
compose_down() { compose_cmd down "$@"; }
compose_ps()   { compose_cmd ps "$@"; }
compose_logs() { compose_cmd logs "$@"; }
