using System.Diagnostics;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services;

public sealed class SearchService(
    IHttpClientFactory httpClientFactory,
    ICacheService cache,
    IRequestLogService requestLog,
    IOptions<CacheOptions> cacheOptions,
    ILogger<SearchService> logger) : ISearchService
{
    public async Task<SearchResponse> SearchAsync(SearchRequest request, CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();
        var normalizedQuery = QueryNormalizer.Normalize(request.Query);
        if (string.IsNullOrWhiteSpace(normalizedQuery))
        {
            throw new ArgumentException("Query is required.", nameof(request));
        }

        var maxResults = Math.Clamp(request.MaxResults, 1, 50);
        var cacheKey = CacheKeyHelper.SearchKey(normalizedQuery, maxResults);
        var cached = await cache.GetAsync<CachedSearchPayload>(cacheKey, cancellationToken);
        if (cached is not null)
        {
            sw.Stop();
            await requestLog.LogAsync("search", normalizedQuery, "searxng", sw.ElapsedMilliseconds, true, cancellationToken);
            return new SearchResponse(cached.Results, true);
        }

        var client = httpClientFactory.CreateClient("searxng");
        var response = await client.GetAsync(
            $"/search?q={Uri.EscapeDataString(normalizedQuery)}&format=json",
            cancellationToken);
        response.EnsureSuccessStatusCode();

        var payload = await response.Content.ReadFromJsonAsync<SearXngResponse>(cancellationToken)
            ?? throw new InvalidOperationException("SearXNG returned an empty response.");

        var raw = payload.Results.Select(r => new SearXngRawResult
        {
            Title = r.Title,
            Url = r.Url,
            Content = r.Content,
            Engine = r.Engine,
            Engines = r.Engines,
            Positions = r.Positions,
            Position = r.Position,
        });

        var merged = SearchResultMerger.Merge(raw, maxResults);
        var results = merged
            .Select(m => new
            {
                Merged = m,
                Score = SearchResultScorer.Score(new SearchResultScoreInput
                {
                    Title = m.Title,
                    Url = m.Url,
                    Snippet = m.Snippet,
                    Engines = m.Engines,
                    Positions = m.Positions,
                }, normalizedQuery),
            })
            .OrderByDescending(x => x.Score)
            .Take(maxResults)
            .Select(x => new SearchResultItem(
                x.Merged.Title,
                x.Merged.Url,
                x.Merged.Snippet,
                x.Merged.Engines.FirstOrDefault(),
                x.Score,
                x.Merged.Engines))
            .ToList();

        var ttl = TimeSpan.FromSeconds(cacheOptions.Value.SearchTtlSeconds);
        await cache.SetAsync(cacheKey, new CachedSearchPayload(results), ttl, cancellationToken);

        sw.Stop();
        await requestLog.LogAsync("search", normalizedQuery, "searxng", sw.ElapsedMilliseconds, false, cancellationToken);
        logger.LogInformation("Search completed for {Query} in {Ms}ms", normalizedQuery, sw.ElapsedMilliseconds);

        return new SearchResponse(results, false);
    }

    private sealed record CachedSearchPayload(IReadOnlyList<SearchResultItem> Results);

    private sealed class SearXngResponse
    {
        [JsonPropertyName("results")]
        public List<SearXngResult> Results { get; set; } = [];
    }

    private sealed class SearXngResult
    {
        [JsonPropertyName("title")]
        public string Title { get; set; } = string.Empty;

        [JsonPropertyName("url")]
        public string Url { get; set; } = string.Empty;

        [JsonPropertyName("content")]
        public string? Content { get; set; }

        [JsonPropertyName("engine")]
        public string? Engine { get; set; }

        [JsonPropertyName("engines")]
        public List<string>? Engines { get; set; }

        [JsonPropertyName("positions")]
        public List<int>? Positions { get; set; }

        [JsonPropertyName("position")]
        public int? Position { get; set; }
    }
}
