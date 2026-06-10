import re
import httpx
import trafilatura
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="crawl-svc", version="2.0.0")

HTTPX_TIMEOUT = 10
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


class CrawlRequest(BaseModel):
    url: str


class CrawlResponse(BaseModel):
    content: str | None
    success: bool
    source: str


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/crawl", response_model=CrawlResponse)
async def crawl(body: CrawlRequest):
    html = await _fetch_httpx(body.url)
    if html:
        content = _extract(html)
        if content:
            return CrawlResponse(content=content, success=True, source="httpx")
    return CrawlResponse(content=None, success=False, source="none")
