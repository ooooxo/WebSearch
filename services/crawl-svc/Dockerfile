# 使用官方 Playwright Python 镜像作为基础
# Chromium + 所有系统依赖已预装，无需在构建时下载浏览器
FROM mcr.microsoft.com/playwright/python:v1.49.1-jammy

WORKDIR /app

# curl 用于 HEALTHCHECK
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# 只安装轻量业务依赖（playwright 已在基础镜像中）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8001

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
