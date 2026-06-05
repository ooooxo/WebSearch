#!/usr/bin/env bash
# 补全 / 修复 .env 中缺失的变量（兼容旧版 .env）

_unquote_env_value() {
    local value="$1"
    if [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\"(.*)\"$ ]]; then
        value="${BASH_REMATCH[1]}"
    fi
    printf '%s' "$value"
}

_quote_env_value() {
    env_quote "$(_unquote_env_value "$1")"
}

fix_env_quoting() {
    local env_file="$1"
    local line key value tmp changed=false

    [[ -f "$env_file" ]] || return 0

    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^(POSTGRES_CONNECTION|POSTGRES_PASSWORD|REDIS_CONNECTION|SEARXNG_SECRET_KEY|FIRECRAWL_API_KEY|JINA_API_KEY)= ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            line="${key}=$(_quote_env_value "$value")"
            changed=true
        fi
        printf '%s\n' "$line" >> "$tmp"
    done < "$env_file"

    if [[ "$changed" == "true" ]]; then
        mv "$tmp" "$env_file"
        chmod 600 "$env_file"
        ok "已修复 .env 引号（双引号，兼容 bash 与 Docker Compose）"
    else
        rm -f "$tmp"
    fi
}

repair_env_file() {
    local env_file="${1:-$PROJECT_ROOT/.env}"
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # shellcheck source=deploy/lib/common.sh
    source "${lib_dir}/common.sh"

    if [[ ! -f "$env_file" ]]; then
        warn "未找到 .env，请先运行 install.sh 完成配置向导。"
        return 1
    fi

    local USE_BUILTIN_REDIS USE_BUILTIN_POSTGRES REDIS_CONNECTION
    local POSTGRES_PASSWORD POSTGRES_CONNECTION

    # 读取已有值（不 source 整文件，避免特殊字符问题）
    USE_BUILTIN_REDIS="$(grep_safe -E '^USE_BUILTIN_REDIS=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    USE_BUILTIN_POSTGRES="$(grep_safe -E '^USE_BUILTIN_POSTGRES=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    REDIS_CONNECTION="$(grep_safe -E '^REDIS_CONNECTION=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//' || true)"
    POSTGRES_PASSWORD="$(grep_safe -E '^POSTGRES_PASSWORD=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//' || true)"
    POSTGRES_CONNECTION="$(grep_safe -E '^POSTGRES_CONNECTION=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//' || true)"

    USE_BUILTIN_REDIS="${USE_BUILTIN_REDIS:-true}"
    USE_BUILTIN_POSTGRES="${USE_BUILTIN_POSTGRES:-true}"
    REDIS_CONNECTION="${REDIS_CONNECTION:-localhost:6379,abortConnect=false}"

    local changed=false

    if ! grep_safe -qE '^USE_BUILTIN_REDIS=' "$env_file"; then
        echo "USE_BUILTIN_REDIS=${USE_BUILTIN_REDIS}" >> "$env_file"
        changed=true
    fi
    if ! grep_safe -qE '^USE_BUILTIN_POSTGRES=' "$env_file"; then
        echo "USE_BUILTIN_POSTGRES=${USE_BUILTIN_POSTGRES}" >> "$env_file"
        changed=true
    fi
    if ! grep_safe -qE '^REDIS_CONNECTION=' "$env_file"; then
        echo "REDIS_CONNECTION=$(_quote_env_value "$REDIS_CONNECTION")" >> "$env_file"
        changed=true
    fi

    if [[ -z "${POSTGRES_CONNECTION}" ]]; then
        if [[ "${USE_BUILTIN_POSTGRES}" == "true" ]]; then
            if [[ -z "${POSTGRES_PASSWORD}" ]]; then
                POSTGRES_PASSWORD="$(generate_secret)"
                echo "POSTGRES_PASSWORD=$(_quote_env_value "$POSTGRES_PASSWORD")" >> "$env_file"
                warn "已自动生成 POSTGRES_PASSWORD 并写入 .env"
            fi
            POSTGRES_CONNECTION="Host=localhost;Port=5432;Database=websearch;Username=websearch;Password=${POSTGRES_PASSWORD}"
        else
            err "USE_BUILTIN_POSTGRES=false 但 .env 缺少 POSTGRES_CONNECTION，请重新运行: sudo bash install.sh"
            return 1
        fi
        echo "POSTGRES_CONNECTION=$(_quote_env_value "$POSTGRES_CONNECTION")" >> "$env_file"
        changed=true
    fi

    fix_env_quoting "$env_file"

    if [[ "$changed" == "true" ]]; then
        chmod 600 "$env_file"
        ok "已补全 .env 缺失项"
    fi

    export_env_for_compose "$env_file"
}

export_env_for_compose() {
    local env_file="${1:-$PROJECT_ROOT/.env}"
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # shellcheck source=deploy/lib/common.sh
    source "${lib_dir}/common.sh"
    fix_env_quoting "$env_file"
    load_env_file "$env_file"

    export USE_BUILTIN_REDIS="${USE_BUILTIN_REDIS:-true}"
    export USE_BUILTIN_POSTGRES="${USE_BUILTIN_POSTGRES:-true}"
    export REDIS_CONNECTION="${REDIS_CONNECTION:-localhost:6379,abortConnect=false}"
    export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

    if [[ -z "${POSTGRES_CONNECTION:-}" ]]; then
        if [[ "${USE_BUILTIN_POSTGRES}" == "true" && -n "${POSTGRES_PASSWORD}" ]]; then
            export POSTGRES_CONNECTION="Host=localhost;Port=5432;Database=websearch;Username=websearch;Password=${POSTGRES_PASSWORD}"
        fi
    else
        export POSTGRES_CONNECTION
    fi
}
