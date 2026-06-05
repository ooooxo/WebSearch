#!/usr/bin/env bash
# 单独修复旧版 .env 缺失字段
# 用法: bash deploy/repair-env.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=deploy/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=deploy/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"

cd "$PROJECT_ROOT"
repair_env_file "$PROJECT_ROOT/.env"

echo ""
info "当前 PostgreSQL 连接已配置（密码已隐藏）。"
grep_safe '^POSTGRES_CONNECTION=' .env | sed 's/Password=.*/Password=***/'
grep_safe '^REDIS_CONNECTION=' .env || true
