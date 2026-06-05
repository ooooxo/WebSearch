#!/usr/bin/env bash
# WebSearch 一键安装入口
# 用法: sudo bash install.sh
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/setup-vps.sh" "$@"
