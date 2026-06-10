#!/usr/bin/env bash
# WebSearch 一键部署入口
# 用法: sudo bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec bash "$SCRIPT_DIR/deploy/setup-vps.sh" "$@"
