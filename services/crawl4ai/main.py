from fastapi import FastAPI
from pydantic import BaseModel, HttpUrl
from crawl4ai import AsyncWebCrawler

app = FastAPI(title="Crawl4AI Sidecar", version="1.0.0")


class CrawlRequest(BaseModel):
    url: HttpUrl


class CrawlResponse(BaseModel):
    content: str | None
    success: bool


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/crawl", response_model=CrawlResponse)
async def crawl(body: CrawlRequest):
    async with AsyncWebCrawler() as crawler:
        result = await crawler.arun(url=str(body.url))
        return CrawlResponse(
            content=result.markdown if result.success else None,
            success=result.success,
        )
