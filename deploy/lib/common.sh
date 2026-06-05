#!/usr/bin/env bash
# Shared helpers for WebSearch deploy scripts.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${BOLD}${CYAN}==> $*${NC}\n"; }

# 部分 VPS 把 grep alias 成 rg，-E 会报错；统一走系统 grep
grep_safe() {
    if [[ -x /usr/bin/grep ]]; then
        /usr/bin/grep "$@"
    else
        command grep "$@"
    fi
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        err "请使用 root 运行: sudo bash deploy/setup-vps.sh"
        exit 1
    fi
}

prompt() {
    local var_name="$1"
    local message="$2"
    local default="${3:-}"
    local secret="${4:-false}"
    local value=""

    # secret 模式：允许留空，由调用方自动生成
    if [[ "$secret" == "true" ]]; then
        read -r -s -p "${message} [回车自动生成]: " value
        echo ""
        value="${value:-$default}"
        printf -v "$var_name" '%s' "$value"
        return
    fi

    if [[ -n "${default}" ]]; then
        read -r -p "${message} [${default}]: " value
        value="${value:-$default}"
    else
        while [[ -z "${value:-}" ]]; do
            read -r -p "${message}: " value
            if [[ -z "${value}" ]]; then
                warn "此项不能为空。"
            fi
        done
    fi

    printf -v "$var_name" '%s' "$value"
}

prompt_optional() {
    local var_name="$1"
    local message="$2"
    local value=""
    read -r -p "${message} (可选，直接回车跳过): " value
    printf -v "$var_name" '%s' "$value"
}

prompt_yn() {
    local message="$1"
    local default="${2:-y}"
    local hint="Y/n"
    [[ "$default" == "n" ]] && hint="y/N"

    while true; do
        read -r -p "${message} (${hint}): " answer
        answer="${answer:-$default}"
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *) warn "请输入 y 或 n" ;;
        esac
    done
}

generate_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 24
    else
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48
    fi
}

# 写入 .env 时用双引号包裹（bash source 与 Docker Compose 均兼容；单引号会被 Docker 原样传入容器）
env_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    value="${value//\`/\\\`}"
    printf '"%s"' "$value"
}

load_env_file() {
    local env_file="${1:-.env}"
    if [[ ! -f "$env_file" ]]; then
        err "未找到 ${env_file}"
        return 1
    fi
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
}

ensure_command() {
    local cmd="$1"
    local install_hint="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    err "缺少命令: ${cmd}"
    [[ -n "$install_hint" ]] && info "$install_hint"
    return 1
}

ensure_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        ok "Docker: $(docker --version)"
        ok "Compose: $(docker compose version)"
        return 0
    fi

    warn "未检测到 Docker。"
    if prompt_yn "是否现在安装 Docker?" "y"; then
        curl -fsSL https://get.docker.com | sh
        ok "Docker 安装完成"
    else
        err "需要 Docker 才能继续。"
        exit 1
    fi
}

ensure_curl() {
    if command -v curl >/dev/null 2>&1; then
        return 0
    fi
    apt-get update && apt-get install -y curl
}

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     WebSearch VPS 一键部署向导       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
}
