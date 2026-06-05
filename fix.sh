#!/usr/bin/env bash
# WebSearch 傻瓜式一键修复
# 用法: sudo bash fix.sh

exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/fix-all.sh" "$@"
