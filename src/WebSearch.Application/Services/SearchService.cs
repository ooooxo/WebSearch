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
    IOptions<TavilyOptions> tavilyOptions,
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
            await requestLog.LogSearchAsync(request.Query, normalizedQuery, cached.Source,
                cached.Results.Count, sw.ElapsedMilliseconds, true, cancellationToken);
            return new SearchResponse(cached.Results, true, cached.Source);
        }

        var results = await FetchSearXngAsync(normalizedQuery, maxResults, cancellationToken);
        var source = "searxng";

        var tavily = tavilyOptions.Value;
        var avgScore = results.Count > 0 ? results.Average(r => r.Score) : 0f;
        if (tavily.IsConfigured && (results.Count < tavily.MinResultCount || avgScore < tavily.MinAverageScore))
        {
            var tavilyResults = await FetchTavilyAsync(normalizedQuery, maxResults, cancellationToken);
            if (tavilyResults.Count > 0)
            {
                var existingUrls = results.Select(r => r.Url).ToHashSet(StringComparer.OrdinalIgnoreCase);
                var newItems = tavilyResults.Where(r => !existingUrls.Contains(r.Url));
                results = results.Concat(newItems)
                    .OrderByDescending(r => r.Score)
                    .Take(maxResults)
                    .ToList();
                source = "searxng+tavily";
            }
        }

        var ttl = TimeSpan.FromSeconds(cacheOptions.Value.SearchTtlSeconds);
        await cache.SetAsync(cacheKey, new CachedSearchPayload(results, source), ttl, cancellationToken);

        sw.Stop();
        await requestLog.LogSearchAsync(request.Query, normalizedQuery, source,
            results.Count, sw.ElapsedMilliseconds, false, cancellationToken);
        logger.LogInformation("Search completed for {Query} via {Source} in {Ms}ms", normalizedQuery, source, sw.ElapsedMilliseconds);

        return new SearchResponse(results, false, source);
    }

    private async Task<List<SearchResultItem>> FetchSearXngAsync(
        string normalizedQuery, int maxResults, CancellationToken cancellationToken)
    {
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
        return merged
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
    }

    private async Task<List<SearchResultItem>> FetchTavilyAsync(
        string query, int maxResults, CancellationToken cancellationToken)
    {
        try
        {
            var client = httpClientFactory.CreateClient("tavily");
            var response = await client.PostAsJsonAsync("search", new
            {
                query,
                max_results = Math.Min(maxResults, 10),
            }, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                return [];
            }

            var payload = await response.Content.ReadFromJsonAsync<TavilyResponse>(cancellationToken);
            if (payload?.Results is null)
            {
                return [];
            }

            return payload.Results
                .Select(r => new SearchResultItem(
                    r.Title ?? string.Empty,
                    r.Url ?? string.Empty,
                    r.Content,
                    "tavily",
                    (float)(r.Score ?? 0.5),
                    ["tavily"]))
                .Where(r => !string.IsNullOrWhiteSpace(r.Url))
                .ToList();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Tavily search failed for {Query}", query);
            return [];
        }
    }

    private sealed record CachedSearchPayload(IReadOnlyList<SearchResultItem> Results, string Source);

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

    private sealed class TavilyResponse
    {
        [JsonPropertyName("results")]
        public List<TavilyResult>? Results { get; set; }
    }

    private sealed class TavilyResult
    {
        [JsonPropertyName("title")]
        public string? Title { get; set; }

        [JsonPropertyName("url")]
        public string? Url { get; set; }

        [JsonPropertyName("content")]
        public string? Content { get; set; }

        [JsonPropertyName("score")]
        public double? Score { get; set; }
    }
}
