#!/usr/bin/env bash
# 安装前清理 / 卸载逻辑

cleanup_before_install() {
    local site="${NGINX_SITE_NAME:-websearch}"

    step "自动清理旧环境"

    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        repair_env_file "${PROJECT_ROOT}/.env" 2>/dev/null || {
            set -a
            # shellcheck disable=SC1091
            source "${PROJECT_ROOT}/.env"
            set +a
        }
        site="${NGINX_SITE_NAME:-websearch}"
    fi

    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        info "停止并移除 Docker 容器与数据卷..."
        docker compose -f "${PROJECT_ROOT}/docker-compose.yml" \
            down -v --remove-orphans 2>/dev/null || true
        ok "Docker 容器已清理"
    fi

    if [[ -f "/etc/nginx/sites-enabled/${site}" || -f "/etc/nginx/sites-available/${site}" ]]; then
        info "移除 Nginx 站点: ${site}"
        rm -f "/etc/nginx/sites-enabled/${site}" "/etc/nginx/sites-available/${site}"
        if nginx -t 2>/dev/null; then
            systemctl reload nginx 2>/dev/null || true
        fi
        ok "Nginx 配置已清理（证书保留在 /etc/letsencrypt，重装时自动复用）"
    fi

    if command -v docker >/dev/null 2>&1; then
        info "清理旧镜像..."
        docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
            | grep_safe -E '^websearch-|^websearch/' \
            | xargs -r docker rmi -f 2>/dev/null || true
    fi

    ok "旧环境清理完成（.env 已保留，外部 Redis/PostgreSQL 未动）"
}
