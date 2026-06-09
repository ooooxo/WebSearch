#!/usr/bin/env bash
# WebSearch 一键部署入口
# ──────────────────────────────────────────────────────────────────────────
#  用法：
#    bash install.sh              # 部署 Docker 服务（推荐）
#    bash install.sh --nginx      # 部署完后继续配置 Nginx + HTTPS
#    bash install.sh --down       # 停止并清理所有容器和数据卷
#    bash install.sh --no-cache   # 强制重建镜像（不使用构建缓存）
# ──────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 所有 Docker 部署参数透传给 deploy.sh
DEPLOY_ARGS=()
SETUP_NGINX=false

for arg in "$@"; do
    case "$arg" in
        --nginx) SETUP_NGINX=true ;;
        *)       DEPLOY_ARGS+=("$arg") ;;
    esac
done

# Step 1: Docker 服务部署
bash "$SCRIPT_DIR/deploy.sh" "${DEPLOY_ARGS[@]}"

# Step 2: 可选 Nginx + HTTPS 配置
if [[ "$SETUP_NGINX" == "true" ]]; then
    echo ""
    bash "$SCRIPT_DIR/deploy/nginx/setup-nginx.sh"
fi
