using System.Diagnostics;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services;

public sealed class SearchDeepService(
    ISearchService searchService,
    IScrapeService scrapeService,
    ICacheService cache,
    IRequestLogService requestLog,
    IOptions<CacheOptions> cacheOptions,
    ILogger<SearchDeepService> logger) : ISearchDeepService
{
    private const int MaxScrapeLimit = 10;

    public async Task<SearchDeepResponse> SearchDeepAsync(
        SearchDeepRequest request,
        CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();
        var normalizedQuery = QueryNormalizer.Normalize(request.Query);
        if (string.IsNullOrWhiteSpace(normalizedQuery))
        {
            throw new ArgumentException("Query is required.", nameof(request));
        }

        var maxResults = Math.Clamp(request.MaxResults, 1, 50);
        var maxScrape = Math.Clamp(request.MaxScrape, 0, MaxScrapeLimit);
        var minScore = Math.Clamp(request.MinScore, 0f, 1f);

        var cacheKey = CacheKeyHelper.SearchDeepKey(normalizedQuery, maxResults, maxScrape, minScore);
        var cached = await cache.GetAsync<CachedSearchDeepPayload>(cacheKey, cancellationToken);
        if (cached is not null)
        {
            sw.Stop();
            await requestLog.LogSearchAsync(
                request.Query, normalizedQuery, "searxng+crawl",
                cached.Results.Count, sw.ElapsedMilliseconds, true, cancellationToken);
            return new SearchDeepResponse(
                normalizedQuery, cached.Results, true, cached.ScrapedCount, minScore);
        }

        var search = await searchService.SearchAsync(
            new SearchRequest(normalizedQuery, maxResults),
            cancellationToken);

        var scrapeTargets = search.Results
            .Where(r => r.Score > minScore && !string.IsNullOrWhiteSpace(r.Url))
            .Take(maxScrape)
            .Select(r => r.Url)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var enriched = new List<SearchResultEnrichedItem>(search.Results.Count);
        var scrapedCount = 0;

        foreach (var item in search.Results)
        {
            var selected = scrapeTargets.Contains(item.Url);

            if (selected)
            {
                var scrape = await scrapeService.ScrapeAsync(
                    new ScrapeRequest(item.Url, normalizedQuery),
                    cancellationToken);
                if (scrape.Success)
                {
                    scrapedCount++;
                }

                enriched.Add(new SearchResultEnrichedItem(
                    item.Title, item.Url, item.Snippet, item.Engine, item.Score, item.Engines,
                    scrape.Content, scrape.Source, scrape.Success, scrape.CacheHit, true));
            }
            else
            {
                enriched.Add(new SearchResultEnrichedItem(
                    item.Title, item.Url, item.Snippet, item.Engine, item.Score, item.Engines,
                    null, null, false, false, false));
            }
        }

        var ttl = TimeSpan.FromSeconds(cacheOptions.Value.SearchTtlSeconds);
        await cache.SetAsync(cacheKey, new CachedSearchDeepPayload(enriched, scrapedCount), ttl, cancellationToken);

        sw.Stop();
        await requestLog.LogSearchAsync(
            request.Query, normalizedQuery, "searxng+crawl",
            enriched.Count, sw.ElapsedMilliseconds, false, cancellationToken);
        logger.LogInformation(
            "Deep search for {Query}: {ResultCount} results, {ScrapeTargets} scrape targets, {ScrapedCount} scraped in {Ms}ms",
            normalizedQuery, enriched.Count, scrapeTargets.Count, scrapedCount, sw.ElapsedMilliseconds);

        return new SearchDeepResponse(normalizedQuery, enriched, search.CacheHit, scrapedCount, minScore);
    }

    private sealed record CachedSearchDeepPayload(
        IReadOnlyList<SearchResultEnrichedItem> Results,
        int ScrapedCount);
}
