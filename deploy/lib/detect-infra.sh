#!/usr/bin/env bash
# 检测宿主机 / Docker 上是否已有 Redis、PostgreSQL

detect_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tln 2>/dev/null | grep_safe -qE ":${port}[[:space:]]"
        return $?
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | grep_safe -qE ":${port}[[:space:]]"
        return $?
    fi
    return 1
}

detect_docker_container_on_port() {
    local port="$1"
    if ! command -v docker >/dev/null 2>&1; then
        return 0
    fi
    docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null \
        | grep_safe -E "0\.0\.0\.0:${port}->|127\.0\.0\.1:${port}->|\[::\]:${port}->" \
        | head -n 1
}

describe_existing_redis() {
    local line
    line="$(detect_docker_container_on_port 6379)"
    if [[ -n "$line" ]]; then
        echo "$line"
        return 0
    fi
    if detect_port_in_use 6379; then
        echo "(宿主机 6379 端口已占用，非本项目的 Docker 容器)"
        return 0
    fi
    return 1
}

describe_existing_postgres() {
    local line
    line="$(detect_docker_container_on_port 5432)"
    if [[ -n "$line" ]]; then
        echo "$line"
        return 0
    fi
    if detect_port_in_use 5432; then
        echo "(宿主机 5432 端口已占用，非本项目的 Docker 容器)"
        return 0
    fi
    return 1
}

# 从宿主机上的 Docker 容器访问已有服务时，API 容器用此主机名
HOST_GATEWAY="${HOST_GATEWAY:-host.docker.internal}"

default_external_redis_connection() {
    echo "${HOST_GATEWAY}:6379,abortConnect=false"
}

default_external_postgres_connection() {
    local password="${1:-}"
    echo "Host=${HOST_GATEWAY};Port=5432;Database=websearch;Username=websearch;Password=${password}"
}
