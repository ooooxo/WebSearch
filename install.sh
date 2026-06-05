#!/usr/bin/env bash
# 项目根目录快捷入口
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/setup-vps.sh" "$@"
