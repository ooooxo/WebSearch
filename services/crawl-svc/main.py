import re
import asyncio
import httpx
import trafilatura
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="crawl-svc", version="1.0.0")

HTTPX_TIMEOUT = 10
PLAYWRIGHT_TIMEOUT = 15_000  # ms
MIN_CONTENT_CHARS = 200
MIN_PARAGRAPHS = 2
MAX_LINK_DENSITY = 0.5

_HTTPX_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
}


def _is_quality(content: str) -> bool:
    """三道质量门槛：最小字数 / 段落数 / 链接密度。"""
    if len(content) < MIN_CONTENT_CHARS:
        return False
    paragraphs = [p for p in content.split("\n\n") if p.strip()]
    if len(paragraphs) < MIN_PARAGRAPHS:
        return False
    links = re.findall(r"\[.*?\]\(.*?\)", content)
    link_chars = sum(len(lnk) for lnk in links)
    if len(content) > 0 and link_chars / len(content) > MAX_LINK_DENSITY:
        return False
    return True


def _extract(html: str) -> str | None:
    result = trafilatura.extract(
        html,
        include_tables=True,
        include_formatting=True,
        output_format="markdown",
        no_fallback=False,
    )
    if result and _is_quality(result):
        return result.strip()
    return None


async def _fetch_httpx(url: str) -> str | None:
    try:
        async with httpx.AsyncClient(
            follow_redirects=True,
            headers=_HTTPX_HEADERS,
            timeout=HTTPX_TIMEOUT,
        ) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            return resp.text
    except Exception:
        return None


async def _fetch_playwright(url: str) -> str | None:
    try:
        from playwright.async_api import async_playwright

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]
            )
            ctx = await browser.new_context(
                user_agent=_HTTPX_HEADERS["User-Agent"],
                java_script_enabled=True,
            )
            page = await ctx.new_page()
            await page.goto(
                url, wait_until="networkidle", timeout=PLAYWRIGHT_TIMEOUT
            )
            html = await page.content()
            await browser.close()
            return html
    except Exception:
        return None


class CrawlRequest(BaseModel):
    url: str
    query: str | None = None  # reserved — not used by trafilatura path


class CrawlResponse(BaseModel):
    content: str | None
    success: bool
    source: str  # "httpx" | "playwright" | "none"


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/crawl", response_model=CrawlResponse)
async def crawl(body: CrawlRequest):
    # Stage 1: fast static fetch
    html = await _fetch_httpx(body.url)
    if html:
        content = _extract(html)
        if content:
            return CrawlResponse(content=content, success=True, source="httpx")

    # Stage 2: JS-rendered page
    html = await _fetch_playwright(body.url)
    if html:
        content = _extract(html)
        if content:
            return CrawlResponse(content=content, success=True, source="playwright")

    return CrawlResponse(content=None, success=False, source="none")
