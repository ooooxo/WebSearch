#!/usr/bin/env bash
# WebSearch 仅卸载（install.sh 重装时会自动清理，一般不需要单独运行）
# 用法: sudo bash uninstall.sh
# 选项:
#   --purge-volumes   删除内置 PostgreSQL 数据卷
#   --remove-nginx    删除 Nginx 站点（默认会删）
#   --remove-env      删除 .env
#   --prune-images    删除镜像（默认会删）
#   --yes             跳过确认

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/lifecycle.sh
source "$SCRIPT_DIR/lib/lifecycle.sh"

PURGE_VOLUMES=true
REMOVE_NGINX=true
REMOVE_ENV=false
PRUNE_IMAGES=true
ASSUME_YES=false

for arg in "$@"; do
    case "$arg" in
        --purge-volumes) PURGE_VOLUMES=true ;;
        --no-purge-volumes) PURGE_VOLUMES=false ;;
        --remove-nginx)  REMOVE_NGINX=true ;;
        --keep-nginx)    REMOVE_NGINX=false ;;
        --remove-env)    REMOVE_ENV=true ;;
        --prune-images)  PRUNE_IMAGES=true ;;
        --keep-images)   PRUNE_IMAGES=false ;;
        --yes|-y)        ASSUME_YES=true ;;
        -h|--help)
            echo "用法: sudo bash uninstall.sh [选项]"
            echo ""
            echo "  --remove-env      同时删除 .env"
            echo "  --no-purge-volumes  保留 PostgreSQL 数据卷"
            echo "  --keep-nginx      保留 Nginx 配置"
            echo "  --yes             跳过确认"
            exit 0
            ;;
        *) err "未知参数: $arg"; exit 1 ;;
    esac
done

require_root
cd "$PROJECT_ROOT"

banner
echo -e "${YELLOW}  WebSearch 卸载${NC}"
echo ""

if [[ "${ASSUME_YES}" != "true" ]]; then
    echo "将停止容器、删除数据卷与镜像。"
    [[ "${REMOVE_NGINX}" == "true" ]] && echo "将删除 Nginx 反代配置。"
    [[ "${REMOVE_ENV}" == "true" ]] && echo "将删除 .env。"
    echo ""
    warn "外部 Redis/PostgreSQL 不会被删除。"
    echo ""
    if ! prompt_yn "确认卸载?" "n"; then
        info "已取消。"
        exit 0
    fi
fi

if [[ "${PURGE_VOLUMES}" == "true" && "${REMOVE_NGINX}" == "true" && "${PRUNE_IMAGES}" == "true" ]]; then
    cleanup_before_install
else
    step "自定义卸载"
    if [[ -f docker-compose.yml ]]; then
        local_args=(down --remove-orphans)
        [[ "${PURGE_VOLUMES}" == "true" ]] && local_args+=(-v)
        docker compose -f docker-compose.yml "${local_args[@]}" 2>/dev/null || true
    fi
    if [[ "${REMOVE_NGINX}" == "true" ]]; then
        site="${NGINX_SITE_NAME:-websearch}"
        [[ -f .env ]] && source .env && site="${NGINX_SITE_NAME:-websearch}"
        rm -f "/etc/nginx/sites-enabled/${site}" "/etc/nginx/sites-available/${site}"
        nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    fi
    if [[ "${PRUNE_IMAGES}" == "true" ]]; then
        docker images --format '{{.Repository}}:{{.Tag}}' \
            | grep_safe -E '^websearch-|^websearch/' \
            | xargs -r docker rmi -f 2>/dev/null || true
    fi
fi

if [[ "${REMOVE_ENV}" == "true" && -f .env ]]; then
    rm -f .env
    ok "已删除 .env"
fi

echo ""
echo -e "${GREEN}卸载完成。${NC}"
echo "  重新部署: sudo bash install.sh"
echo ""
