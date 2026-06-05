#!/usr/bin/env bash
# 检测外部 Docker 容器网络，生成 compose override 使 API 能直连外部容器
#
# 问题根因：game-redis/game-postgres 绑定在宿主机 127.0.0.1，
# 而 host.docker.internal 在 Linux 上解析为 Docker bridge 网关 IP（172.17.0.1），
# 两者不同，所以 API 容器无法通过 host.docker.internal 访问 127.0.0.1 绑定的服务。
#
# 解决：让 API 容器加入 game 容器所在的 Docker 网络，直接用容器名连接。

COMPOSE_OVERRIDE_FILE="${PROJECT_ROOT:-$(pwd)}/docker-compose.prod.override.yml"

# 返回在指定端口上监听的 Docker 容器名（第一个）
container_name_on_port() {
    local port="$1"
    docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null \
        | while IFS=$'\t' read -r name ports; do
            if echo "$ports" | grep_safe -q ":${port}->"; then
                echo "$name"
                break
            fi
        done
}

# 返回容器所在的第一个非默认 Docker 网络名
container_primary_network() {
    local name="$1"
    docker inspect "$name" \
        --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
        2>/dev/null \
        | tr ' ' '\n' \
        | while IFS= read -r net; do
            [[ -z "$net" ]] && continue
            [[ "$net" == "bridge" ]] && continue
            [[ "$net" == "host" ]] && continue
            [[ "$net" == "none" ]] && continue
            echo "$net"
            return 0
        done
}

# 用 Python 更新 .env 中指定 key 的值（保留双引号格式，安全替换主机名部分）
_update_env_connection_host() {
    local env_file="$1"
    local key="$2"
    local old_host="$3"
    local new_host="$4"

    python3 - "$env_file" "$key" "$old_host" "$new_host" <<'PYEOF'
import sys, re

env_file, key, old_host, new_host = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(env_file) as f:
    content = f.read()

def replacer(m):
    val = m.group(2)
    # For Redis: replace host part before ':'
    if key == 'REDIS_CONNECTION':
        val = re.sub(re.escape(old_host), new_host, val)
    # For Postgres: replace Host=xxx
    elif key == 'POSTGRES_CONNECTION':
        val = re.sub(r'Host=' + re.escape(old_host), 'Host=' + new_host, val, flags=re.IGNORECASE)
    return m.group(1) + val + m.group(3)

# Match both quoted and unquoted values
pattern = r'^(' + re.escape(key) + r'=")([^"]*)"'
new_content = re.sub(pattern, replacer, content, flags=re.MULTILINE)

# If key was unquoted, also try without quotes
if new_content == content:
    pattern2 = r'^(' + re.escape(key) + r'=)([^\n"\']+)'
    new_content = re.sub(pattern2, replacer, content, flags=re.MULTILINE)

if new_content != content:
    with open(env_file, 'w') as f:
        f.write(new_content)
    print(f"[updated] {key}: {old_host} -> {new_host}")
else:
    print(f"[skip] {key}: '{old_host}' not found in value")
PYEOF
}

# 核心函数：检测外部容器网络，更新连接串，生成 compose override
setup_container_networking() {
    local root="${PROJECT_ROOT:-$(pwd)}"
    local override="${root}/docker-compose.prod.override.yml"

    # 仅当使用外部 Redis 或外部 Postgres 时才需要
    if [[ "${USE_BUILTIN_REDIS:-true}" == "true" ]] && [[ "${USE_BUILTIN_POSTGRES:-true}" == "true" ]]; then
        rm -f "$override" 2>/dev/null || true
        return 0
    fi

    info "检测外部 Docker 容器网络..."

    local redis_container="" redis_net=""
    local pg_container="" pg_net=""

    if [[ "${USE_BUILTIN_REDIS:-true}" == "false" ]]; then
        redis_container="$(container_name_on_port 6379)"
        if [[ -n "$redis_container" ]]; then
            redis_net="$(container_primary_network "$redis_container")"
            ok "Redis 容器: ${redis_container}，网络: ${redis_net:-bridge（无独立网络）}"

            if [[ -n "$redis_net" ]]; then
                _update_env_connection_host "$root/.env" "REDIS_CONNECTION" \
                    "host.docker.internal" "$redis_container"
                _update_env_connection_host "$root/.env" "REDIS_CONNECTION" \
                    "127.0.0.1" "$redis_container"
            fi
        else
            warn "端口 6379 未检测到 Docker 容器（可能是宿主机进程），将保留 host.docker.internal"
        fi
    fi

    if [[ "${USE_BUILTIN_POSTGRES:-true}" == "false" ]]; then
        pg_container="$(container_name_on_port 5432)"
        if [[ -n "$pg_container" ]]; then
            pg_net="$(container_primary_network "$pg_container")"
            ok "PostgreSQL 容器: ${pg_container}，网络: ${pg_net:-bridge（无独立网络）}"

            if [[ -n "$pg_net" ]]; then
                _update_env_connection_host "$root/.env" "POSTGRES_CONNECTION" \
                    "host.docker.internal" "$pg_container"
                _update_env_connection_host "$root/.env" "POSTGRES_CONNECTION" \
                    "127.0.0.1" "$pg_container"
            fi
        else
            warn "端口 5432 未检测到 Docker 容器（可能是宿主机进程），将保留 host.docker.internal"
        fi
    fi

    # 收集需要加入的外部网络（去重）
    local net1="" net2=""
    net1="$redis_net"
    if [[ -n "$pg_net" ]] && [[ "$pg_net" != "$net1" ]]; then
        net2="$pg_net"
    fi

    if [[ -z "$net1" ]] && [[ -z "$net2" ]]; then
        warn "未找到可加入的外部 Docker 网络，跳过 override 生成"
        warn "若 Redis/PG 是宿主机原生进程（非容器），需将连接串改为 host.docker.internal 或实际 IP"
        rm -f "$override" 2>/dev/null || true
        return 0
    fi

    # 生成 override YAML
    {
        printf '# Auto-generated by WebSearch fix/install — do not edit manually\n'
        printf 'services:\n'
        printf '  api:\n'
        printf '    networks:\n'
        printf '      - websearch\n'
        [[ -n "$net1" ]] && printf '      - ext_net_0\n'
        [[ -n "$net2" ]] && printf '      - ext_net_1\n'
        printf 'networks:\n'
        if [[ -n "$net1" ]]; then
            printf '  ext_net_0:\n'
            printf '    external: true\n'
            printf '    name: "%s"\n' "$net1"
        fi
        if [[ -n "$net2" ]]; then
            printf '  ext_net_1:\n'
            printf '    external: true\n'
            printf '    name: "%s"\n' "$net2"
        fi
    } > "$override"

    ok "已生成 Compose 网络 override: docker-compose.prod.override.yml"
    [[ -n "$net1" ]] && info "  API 将加入外部网络: ${net1}"
    [[ -n "$net2" ]] && info "  API 将加入外部网络: ${net2}"

    # 重新导出更新后的 .env 到当前 shell
    export_env_for_compose "$root/.env" 2>/dev/null || true
}
