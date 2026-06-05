#!/usr/bin/env bash
# 基础工具库 — 颜色输出 / 密钥生成 / 端口检测 / 容器检测 / 交互提示

readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC}  $*" >&2; }
step() { echo ""; echo -e "${CYAN}==> $*${NC}"; }

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     WebSearch VPS 一键部署向导       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
}

require_root() {
    [[ $EUID -eq 0 ]] || { err "请用 sudo 运行此脚本"; exit 1; }
}

ensure_docker() {
    command -v docker >/dev/null 2>&1 || { err "未安装 Docker，请先安装"; exit 1; }
    ok "Docker: $(docker --version)"
    if docker compose version >/dev/null 2>&1; then
        ok "Compose: $(docker compose version)"
    elif command -v docker-compose >/dev/null 2>&1; then
        ok "Compose: $(docker-compose --version)"
    else
        err "未找到 docker compose 或 docker-compose"; exit 1
    fi
}

ensure_curl() {
    command -v curl >/dev/null 2>&1 || apt-get install -y curl -qq >/dev/null 2>&1
}

# 生成 URL-safe 随机密钥（仅 a-zA-Z0-9_- 无需转义）
generate_secret() {
    python3 -c "import secrets; print(secrets.token_urlsafe(32))"
}

# 端口是否在监听
port_in_use() {
    local port="$1"
    ss -tln 2>/dev/null | /usr/bin/grep -qE ":${port}[[:space:]]" \
        || netstat -tln 2>/dev/null | /usr/bin/grep -qE ":${port}[[:space:]]" \
        || false
}

# 找到占用该端口的 Docker 容器（返回完整信息行）
container_on_port() {
    local port="$1"
    docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null \
        | /usr/bin/grep -E "(0\.0\.0\.0|127\.0\.0\.1|\[::\]):${port}->" \
        | head -1
}

# 只返回容器名
container_name_on_port() {
    container_on_port "$1" | awk '{print $1}'
}

# 交互提示：带默认值
# 用法: prompt VAR_NAME "提示文字" "默认值"
prompt() {
    local _var="$1" _msg="$2" _default="${3:-}"
    local _input
    if [[ -n "$_default" ]]; then
        read -r -p "  ${_msg} [${_default}]: " _input
        printf -v "$_var" '%s' "${_input:-$_default}"
    else
        read -r -p "  ${_msg}: " _input
        printf -v "$_var" '%s' "$_input"
    fi
}

# 交互提示：是/否
# 用法: prompt_yn "提示" "y"|"n"  → 返回 0=yes, 1=no
prompt_yn() {
    local _msg="$1" _default="${2:-y}"
    local _hint _input
    [[ "$_default" == "y" ]] && _hint="Y/n" || _hint="y/N"
    read -r -p "${_msg} (${_hint}): " _input
    _input="${_input:-$_default}"
    [[ "${_input,,}" =~ ^y ]]
}

# 兼容 rg 别名的 grep
grep_safe() { /usr/bin/grep "$@"; }
