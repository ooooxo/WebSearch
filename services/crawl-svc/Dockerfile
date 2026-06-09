FROM python:3.12-slim

WORKDIR /app

# curl for health-check / debug
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Chromium + system deps for Playwright
RUN playwright install chromium
RUN playwright install-deps chromium

COPY main.py .

EXPOSE 8001

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
