#!/usr/bin/env bash
# Docker Compose 辅助：按 .env 决定是否启动内置 Redis / PostgreSQL

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"

_prepare_compose_env() {
    local lib_dir root
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="${PROJECT_ROOT:-$(cd "$lib_dir/../.." && pwd)}"

    [[ -f "${root}/.env" ]] || return 0

    # shellcheck source=deploy/lib/common.sh
    source "${lib_dir}/common.sh"
    # shellcheck source=deploy/lib/env.sh
    source "${lib_dir}/env.sh"
    PROJECT_ROOT="$root"
    repair_env_file "${root}/.env" || true
}

compose_profile_args() {
    local args=()
    if [[ "${USE_BUILTIN_REDIS:-true}" == "true" ]]; then
        args+=(--profile builtin-redis)
    fi
    if [[ "${USE_BUILTIN_POSTGRES:-true}" == "true" ]]; then
        args+=(--profile builtin-postgres)
    fi
    printf '%s\n' "${args[@]}"
}

compose_cmd() {
    _prepare_compose_env
    local -a profiles
    mapfile -t profiles < <(compose_profile_args)
    docker compose -f "$COMPOSE_FILE" "${profiles[@]}" "$@"
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
