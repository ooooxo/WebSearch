using System.Text.Json.Serialization;

namespace WebSearch.Application.Models;

public sealed record SearchRequest(
    string Query,
    [property: JsonPropertyName("max_results")] int MaxResults = 10);

public sealed record SearchResultItem(string Title, string Url, string? Snippet, string? Engine);

public sealed record SearchResponse(
    IReadOnlyList<SearchResultItem> Results,
    bool CacheHit,
    string Source = "searxng");
