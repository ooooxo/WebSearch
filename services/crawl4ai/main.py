from fastapi import FastAPI
from pydantic import BaseModel, HttpUrl, Field

from crawl4ai import AsyncWebCrawler, CacheMode, CrawlerRunConfig
from crawl4ai.content_filter_strategy import BM25ContentFilter, PruningContentFilter
from crawl4ai.markdown_generation_strategy import DefaultMarkdownGenerator

app = FastAPI(title="Crawl4AI Sidecar", version="2.0.0")

# HTML 阶段粗过滤：在 content filter 之前去掉明显噪音
_EXCLUDED_TAGS = [
    "nav",
    "footer",
    "header",
    "aside",
    "script",
    "style",
    "noscript",
    "form",
    "iframe",
    "svg",
]


def _build_run_config(query: str | None) -> CrawlerRunConfig:
    """两层过滤：CrawlerRunConfig 粗过滤 + Pruning/BM25 精过滤。"""
    normalized = (query or "").strip()

    if normalized:
        content_filter = BM25ContentFilter(
            user_query=normalized,
            bm25_threshold=1.0,
        )
    else:
        content_filter = PruningContentFilter(
            threshold=0.45,
            threshold_type="dynamic",
            min_word_threshold=5,
        )

    return CrawlerRunConfig(
        cache_mode=CacheMode.BYPASS,
        word_count_threshold=10,
        excluded_tags=_EXCLUDED_TAGS,
        exclude_external_links=True,
        markdown_generator=DefaultMarkdownGenerator(content_filter=content_filter),
    )


def _extract_content(result) -> str | None:
    """优先返回 fit_markdown（过滤后），空则回退 raw_markdown。"""
    if not result.success:
        return None

    markdown = result.markdown
    if markdown is None:
        return None

    fit = getattr(markdown, "fit_markdown", None)
    if isinstance(fit, str) and fit.strip():
        return fit.strip()

    raw = getattr(markdown, "raw_markdown", None)
    if isinstance(raw, str) and raw.strip():
        return raw.strip()

    # 兼容旧版：markdown 可能直接是字符串
    if isinstance(markdown, str) and markdown.strip():
        return markdown.strip()

    return None


class CrawlRequest(BaseModel):
    url: HttpUrl
    query: str | None = Field(
        default=None,
        description="Optional search query; enables BM25ContentFilter when set.",
    )


class CrawlResponse(BaseModel):
    content: str | None
    success: bool
    filter: str  # "bm25" | "pruning" | "none"


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/crawl", response_model=CrawlResponse)
async def crawl(body: CrawlRequest):
    config = _build_run_config(body.query)
    filter_name = "bm25" if (body.query or "").strip() else "pruning"

    async with AsyncWebCrawler() as crawler:
        result = await crawler.arun(url=str(body.url), config=config)
        content = _extract_content(result)
        return CrawlResponse(
            content=content,
            success=result.success and content is not None,
            filter=filter_name if content else "none",
        )
