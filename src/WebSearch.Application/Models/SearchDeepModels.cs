using System.Text.Json.Serialization;

namespace WebSearch.Application.Models;

public sealed record SearchDeepRequest(
    string Query,
    [property: JsonPropertyName("max_results")] int MaxResults = 10,
    [property: JsonPropertyName("max_scrape")] int MaxScrape = 10,
    [property: JsonPropertyName("min_score")] float MinScore = 0.4f);

public sealed record SearchResultEnrichedItem(
    string Title,
    string Url,
    string? Snippet,
    string? Engine,
    float Score,
    [property: JsonPropertyName("engines")] IReadOnlyList<string> Engines,
    string? Content,
    [property: JsonPropertyName("scrape_source")] string? ScrapeSource,
    [property: JsonPropertyName("scrape_success")] bool ScrapeSuccess,
    [property: JsonPropertyName("scrape_cache_hit")] bool ScrapeCacheHit,
    [property: JsonPropertyName("selected_for_scrape")] bool SelectedForScrape);

public sealed record SearchDeepResponse(
    string Query,
    IReadOnlyList<SearchResultEnrichedItem> Results,
    [property: JsonPropertyName("search_cache_hit")] bool SearchCacheHit,
    [property: JsonPropertyName("scraped_count")] int ScrapedCount,
    [property: JsonPropertyName("min_score")] float MinScore,
    [property: JsonPropertyName("search_source")] string SearchSource = "searxng");
