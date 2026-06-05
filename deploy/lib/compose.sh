#!/usr/bin/env bash
# Docker Compose 辅助：按 .env 决定是否启动内置 Redis / PostgreSQL

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"

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
