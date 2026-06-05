#!/usr/bin/env bash
# WebSearch 一键卸载
# 用法: sudo bash deploy/uninstall.sh
# 选项:
#   --purge-volumes   删除内置 PostgreSQL 数据卷（仅 USE_BUILTIN_POSTGRES=true 时有效）
#   --remove-nginx    删除 Nginx 站点配置
#   --remove-env      删除 .env
#   --prune-images    删除本项目构建的 Docker 镜像
#   --yes             跳过确认提示

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"

PURGE_VOLUMES=false
REMOVE_NGINX=false
REMOVE_ENV=false
PRUNE_IMAGES=false
ASSUME_YES=false

for arg in "$@"; do
    case "$arg" in
        --purge-volumes) PURGE_VOLUMES=true ;;
        --remove-nginx)  REMOVE_NGINX=true ;;
        --remove-env)    REMOVE_ENV=true ;;
        --prune-images)  PRUNE_IMAGES=true ;;
        --yes|-y)        ASSUME_YES=true ;;
        -h|--help)
            echo "用法: sudo bash deploy/uninstall.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --purge-volumes   删除内置 PostgreSQL 数据卷"
            echo "  --remove-nginx    删除 /etc/nginx/sites-enabled/websearch"
            echo "  --remove-env      删除项目 .env"
            echo "  --prune-images    删除 websearch 相关镜像"
            echo "  --yes, -y         跳过确认"
            exit 0
            ;;
        *) err "未知参数: $arg"; exit 1 ;;
    esac
done

require_root
cd "$PROJECT_ROOT"

banner
echo -e "${YELLOW}  WebSearch 卸载向导${NC}"
echo ""

API_DOMAIN=""
NGINX_SITE_NAME="websearch"
USE_BUILTIN_REDIS="true"
USE_BUILTIN_POSTGRES="true"

if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
    API_DOMAIN="${API_DOMAIN:-}"
    NGINX_SITE_NAME="${NGINX_SITE_NAME:-websearch}"
fi

echo "将执行以下操作:"
echo "  • 停止并移除 WebSearch Docker 容器（api / searxng / crawl4ai）"
[[ "${USE_BUILTIN_REDIS}" == "true" ]] && echo "  • 停止并移除内置 Redis 容器"
[[ "${USE_BUILTIN_POSTGRES}" == "true" ]] && echo "  • 停止并移除内置 PostgreSQL 容器"
[[ "${PURGE_VOLUMES}" == "true" && "${USE_BUILTIN_POSTGRES}" == "true" ]] && echo "  • ${RED}删除 PostgreSQL 数据卷 postgres_data${NC}"
[[ "${REMOVE_NGINX}" == "true" ]] && echo "  • 删除 Nginx 站点: ${NGINX_SITE_NAME}"
[[ "${REMOVE_ENV}" == "true" ]] && echo "  • 删除 .env"
[[ "${PRUNE_IMAGES}" == "true" ]] && echo "  • 删除本项目 Docker 镜像"
echo ""
warn "不会自动删除：宿主机上复用的外部 Redis / PostgreSQL"
echo ""

if [[ "${ASSUME_YES}" != "true" ]]; then
    if ! prompt_yn "确认卸载?" "n"; then
        info "已取消。"
        exit 0
    fi

    if [[ "${PURGE_VOLUMES}" != "true" && "${USE_BUILTIN_POSTGRES}" == "true" ]]; then
        if prompt_yn "是否同时删除 PostgreSQL 数据卷（不可恢复）?" "n"; then
            PURGE_VOLUMES=true
        fi
    fi

    if [[ "${REMOVE_NGINX}" != "true" && -n "${API_DOMAIN}" ]]; then
        if prompt_yn "是否删除 Nginx 反代配置 (${NGINX_SITE_NAME})?" "y"; then
            REMOVE_NGINX=true
        fi
    elif [[ "${REMOVE_NGINX}" != "true" && -f "/etc/nginx/sites-enabled/${NGINX_SITE_NAME}" ]]; then
        if prompt_yn "是否删除 Nginx 反代配置 (${NGINX_SITE_NAME})?" "y"; then
            REMOVE_NGINX=true
        fi
    fi
fi

step "停止 Docker 服务"

if [[ -f docker-compose.prod.yml ]]; then
    if [[ "${PURGE_VOLUMES}" == "true" ]]; then
        compose_down -v --remove-orphans
        ok "容器与数据卷已移除"
    else
        compose_down --remove-orphans
        ok "容器已移除（数据卷保留）"
    fi
else
    warn "未找到 docker-compose.prod.yml，跳过。"
fi

if [[ "${REMOVE_NGINX}" == "true" ]]; then
    step "清理 Nginx 配置"
    rm -f "/etc/nginx/sites-enabled/${NGINX_SITE_NAME}"
    rm -f "/etc/nginx/sites-available/${NGINX_SITE_NAME}"
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        ok "Nginx 配置已删除并重载"
    else
        warn "Nginx 配置测试失败，请手动检查 /etc/nginx/"
    fi
fi

if [[ "${PRUNE_IMAGES}" == "true" ]]; then
    step "清理 Docker 镜像"
    docker images --format '{{.Repository}}:{{.Tag}}' \
        | grep -E 'websearch|crawl4ai' \
        | xargs -r docker rmi -f 2>/dev/null || true
    ok "镜像清理完成"
fi

if [[ "${REMOVE_ENV}" == "true" && -f .env ]]; then
    rm -f .env
    ok "已删除 .env"
fi

echo ""
echo -e "${GREEN}卸载完成。${NC}"
echo ""
echo "  重新部署:  sudo bash install.sh"
echo "  外部 Redis/PostgreSQL 未被改动。"
echo ""
