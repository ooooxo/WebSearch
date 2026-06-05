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

        var cacheKey = CacheKeyHelper.SearchKey(normalizedQuery, request.MaxResults);
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

        var results = payload.Results
            .Take(request.MaxResults)
            .Select(r => new SearchResultItem(r.Title, r.Url, r.Content, r.Engine))
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
    }
}
