#!/usr/bin/env bash
# Docker Compose 辅助：按 .env 决定是否启动内置 Redis / PostgreSQL

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"

_compose_bin() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
        return 0
    fi
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
        return 0
    fi
    err "未找到 docker compose 或 docker-compose"
    return 1
}

_compose_file_path() {
    local root="${PROJECT_ROOT:-$(pwd)}"
    if [[ "$COMPOSE_FILE" == /* ]]; then
        echo "$COMPOSE_FILE"
    else
        echo "${root}/${COMPOSE_FILE}"
    fi
}

_prepare_compose_env() {
    local lib_dir root
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="${PROJECT_ROOT:-$(cd "$lib_dir/../.." && pwd)}"
    PROJECT_ROOT="$root"

    [[ -f "${root}/.env" ]] || return 0

    # shellcheck source=deploy/lib/common.sh
    source "${lib_dir}/common.sh"
    # shellcheck source=deploy/lib/env.sh
    source "${lib_dir}/env.sh"
    repair_env_file "${root}/.env" || true
}

compose_cmd() {
    if [[ $# -lt 1 ]]; then
        err "compose_cmd: 缺少子命令（如 up / down / ps）"
        return 1
    fi

    _prepare_compose_env

    local compose_bin file_path
    compose_bin="$(_compose_bin)" || return 1
    file_path="$(_compose_file_path)"

    if [[ ! -f "$file_path" ]]; then
        err "未找到 Compose 文件: ${file_path}"
        return 1
    fi

    local -a cmd=()
    # shellcheck disable=SC2206
    cmd=($compose_bin -f "$file_path")

    if [[ "${USE_BUILTIN_REDIS:-true}" == "true" ]]; then
        cmd+=(--profile builtin-redis)
    fi
    if [[ "${USE_BUILTIN_POSTGRES:-true}" == "true" ]]; then
        cmd+=(--profile builtin-postgres)
    fi

    cmd+=("$@")

    info "Compose: ${cmd[*]}"
    "${cmd[@]}"
}

compose_down() {
    compose_cmd down "$@"
}

compose_up() {
    compose_cmd up -d "$@"
}

compose_ps() {
    compose_cmd ps "$@"
}

compose_logs() {
    compose_cmd logs "$@"
}
