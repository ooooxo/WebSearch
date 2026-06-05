# VPS 完整部署指南

本指南将 WebSearch **全部服务**部署到一台 Linux VPS，通过宿主机 **Nginx** 反代 HTTPS 对外暴露 API。

## 架构

```
Internet (HTTPS)
    │
    ▼
Nginx（宿主机，:443）
    │  proxy_pass
    ▼
WebSearch.Api（Docker，127.0.0.1:5080）
    ├── redis（内网，不暴露）
    ├── postgres（内网，不暴露）
    ├── searxng（内网，不暴露）
    └── crawl4ai（内网，不暴露）
```

Redis / PostgreSQL / SearXNG / Crawl4AI **不映射公网端口**，只在 Docker 内网 `websearch` 网络中通信。

---

## 1. VPS 要求

| 项目 | 建议 |
|------|------|
| 系统 | Ubuntu 22.04 / Debian 12 |
| CPU | 2 核+ |
| 内存 | 4 GB+（Crawl4AI 占内存） |
| 磁盘 | 20 GB+ |
| 域名 | 如 `api.yourdomain.com` → VPS IP |

---

## 2. 安装 Docker 与 Nginx

```bash
# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Nginx + Certbot
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx git
```

---

## 3. 拉取代码

```bash
sudo mkdir -p /opt/websearch
sudo chown $USER:$USER /opt/websearch
cd /opt/websearch

git clone <你的仓库地址> .
# 或 scp / rsync 上传
```

---

## 4. 一键部署（推荐）

```bash
cd /opt/websearch
sudo bash install.sh
```

脚本自动完成：

1. 检测/安装 Docker
2. **交互式配置 `.env`**（密码可回车自动生成）
3. 同步 SearXNG `secret_key`
4. `docker compose` 启动全栈
5. Nginx 反代 + Let's Encrypt HTTPS

### 交互向导会问什么

| 步骤 | 内容 | 默认 |
|------|------|------|
| PostgreSQL 密码 | 回车自动生成 | 随机 48 字符 |
| SearXNG 密钥 | 回车自动生成 | 随机 |
| Firecrawl / Jina Key | 可选 | 跳过 |
| 搜索/抓取缓存 TTL | 秒 | 7200 / 86400 |
| API 域名 | 必填 | — |
| Certbot 邮箱 | 必填 | — |

生成的 `.env` 权限为 `600`（仅 root 可读）。

### 非交互部署（CI / 脚本）

```bash
sudo POSTGRES_PASSWORD='your-strong-password' \
     API_DOMAIN=api.example.com \
     CERTBOT_EMAIL=you@example.com \
     FIRECRAWL_API_KEY=optional \
     bash -c 'source deploy/configure-env.sh && run_configure_env_from_env && docker compose -f docker-compose.prod.yml up -d --build'
```

---

## 5. 分步部署（备选）

```bash
# 仅配置 .env
sudo bash deploy/configure-env.sh

# 仅 Docker
docker compose -f docker-compose.prod.yml up -d --build

# 仅 Nginx
sudo bash deploy/nginx/setup-nginx.sh
```

---

## 6. 验证

```bash
# 本机
curl http://127.0.0.1:5080/health

# 公网
curl https://api.yourdomain.com/health
curl "https://api.yourdomain.com/search?query=aspnet+core"
curl -X POST https://api.yourdomain.com/search \
  -H "Content-Type: application/json" \
  -d '{"query":"asyncio最佳实践"}'
curl -X POST https://api.yourdomain.com/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'
```

第二次相同搜索/抓取应返回 `"cacheHit": true`。

---

## 8. 防火墙

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

**不要**开放 6379、5432、8080、8001 到公网。

---

## 9. 日常运维

### 更新版本

```bash
cd /opt/websearch
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

### 查看日志

```bash
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml logs -f crawl4ai
```

### 重启单个服务

```bash
docker compose -f docker-compose.prod.yml restart api
```

### 备份 PostgreSQL

```bash
docker compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U websearch websearch > backup_$(date +%F).sql
```

---

## 10. 本地开发 vs 生产

| 场景 | 命令 |
|------|------|
| **本地开发**（API 用 `dotnet run`） | `docker compose up -d`（仅基础设施） |
| **VPS 生产**（全容器） | `sudo bash install.sh` |

---

## 11. MCP（Claude Desktop / Cursor）

MCP stdio **跑在你本地电脑**，不部署在 VPS 上。

两种方式：

**A. 本地 MCP + 本地基础设施**（开发）

```json
{
  "mcpServers": {
    "websearch": {
      "command": "dotnet",
      "args": ["run", "--project", "/path/to/WebSearch.Mcp"]
    }
  }
}
```

**B. Agent 直接调 VPS API**（推荐生产）

```python
requests.post("https://api.yourdomain.com/search", json={"query": "..."})
requests.post("https://api.yourdomain.com/scrape", json={"url": "..."})
```

---

## 12. 常见问题

### Crawl4AI 首次 scrape 很慢

首次需初始化浏览器，后续会快很多。`proxy_read_timeout` 已设为 300s。

### `/health` 返回 503

Redis 或 PostgreSQL 未就绪。等待 `docker compose ps` 全部 healthy 后重试。

### SearXNG 无结果

确认 `deploy/searxng/settings.yml` 中 `formats` 包含 `json`。

### 内存不足

Crawl4AI 容器已设 `shm_size: 2gb`。VPS 内存小于 4GB 时考虑升级或去掉 Crawl4AI，仅用 Firecrawl/Jina API。
