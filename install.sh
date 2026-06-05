#!/usr/bin/env bash
# WebSearch 傻瓜式一键部署 / 重装
# 每次运行会先自动清理旧环境，再重新安装
#
# 用法: sudo bash install.sh
#
# 流程: 清理旧容器/卷/镜像/Nginx → 配置(.env) → Docker → HTTPS

exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/setup-vps.sh" "$@"
