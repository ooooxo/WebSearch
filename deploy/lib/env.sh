#!/usr/bin/env bash
# 补全 / 修复 .env 中缺失的变量（兼容旧版 .env）

repair_env_file() {
    local env_file="${1:-$PROJECT_ROOT/.env}"

    if [[ ! -f "$env_file" ]]; then
        warn "未找到 .env，请先运行 install.sh 完成配置向导。"
        return 1
    fi

    local USE_BUILTIN_REDIS USE_BUILTIN_POSTGRES REDIS_CONNECTION
    local POSTGRES_PASSWORD POSTGRES_CONNECTION

    # 读取已有值（不 source 整文件，避免特殊字符问题）
    USE_BUILTIN_REDIS="$(grep -E '^USE_BUILTIN_REDIS=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    USE_BUILTIN_POSTGRES="$(grep -E '^USE_BUILTIN_POSTGRES=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    REDIS_CONNECTION="$(grep -E '^REDIS_CONNECTION=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    POSTGRES_CONNECTION="$(grep -E '^POSTGRES_CONNECTION=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"

    USE_BUILTIN_REDIS="${USE_BUILTIN_REDIS:-true}"
    USE_BUILTIN_POSTGRES="${USE_BUILTIN_POSTGRES:-true}"
    REDIS_CONNECTION="${REDIS_CONNECTION:-redis:6379,abortConnect=false}"

    local changed=false

    if ! grep -qE '^USE_BUILTIN_REDIS=' "$env_file"; then
        echo "USE_BUILTIN_REDIS=${USE_BUILTIN_REDIS}" >> "$env_file"
        changed=true
    fi
    if ! grep -qE '^USE_BUILTIN_POSTGRES=' "$env_file"; then
        echo "USE_BUILTIN_POSTGRES=${USE_BUILTIN_POSTGRES}" >> "$env_file"
        changed=true
    fi
    if ! grep -qE '^REDIS_CONNECTION=' "$env_file"; then
        echo "REDIS_CONNECTION=${REDIS_CONNECTION}" >> "$env_file"
        changed=true
    fi

    if [[ -z "${POSTGRES_CONNECTION}" ]]; then
        if [[ "${USE_BUILTIN_POSTGRES}" == "true" ]]; then
            if [[ -z "${POSTGRES_PASSWORD}" ]]; then
                # shellcheck source=deploy/lib/common.sh
                POSTGRES_PASSWORD="$(generate_secret)"
                echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" >> "$env_file"
                warn "已自动生成 POSTGRES_PASSWORD 并写入 .env"
            fi
            POSTGRES_CONNECTION="Host=postgres;Port=5432;Database=websearch;Username=websearch;Password=${POSTGRES_PASSWORD}"
        else
            err "USE_BUILTIN_POSTGRES=false 但 .env 缺少 POSTGRES_CONNECTION，请重新运行: sudo bash install.sh"
            return 1
        fi
        echo "POSTGRES_CONNECTION=${POSTGRES_CONNECTION}" >> "$env_file"
        changed=true
    fi

    if [[ "$changed" == "true" ]]; then
        chmod 600 "$env_file"
        ok "已补全 .env 缺失项"
    fi

    export_env_for_compose "$env_file"
}

export_env_for_compose() {
    local env_file="${1:-$PROJECT_ROOT/.env}"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a

    export USE_BUILTIN_REDIS="${USE_BUILTIN_REDIS:-true}"
    export USE_BUILTIN_POSTGRES="${USE_BUILTIN_POSTGRES:-true}"
    export REDIS_CONNECTION="${REDIS_CONNECTION:-redis:6379,abortConnect=false}"
    export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

    if [[ -z "${POSTGRES_CONNECTION:-}" ]]; then
        if [[ "${USE_BUILTIN_POSTGRES}" == "true" && -n "${POSTGRES_PASSWORD}" ]]; then
            export POSTGRES_CONNECTION="Host=postgres;Port=5432;Database=websearch;Username=websearch;Password=${POSTGRES_PASSWORD}"
        fi
    else
        export POSTGRES_CONNECTION
    fi
}
