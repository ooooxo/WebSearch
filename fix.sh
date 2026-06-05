#!/usr/bin/env bash
# WebSearch 一键修复入口
# 用法: sudo bash fix.sh
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/fix-all.sh" "$@"
