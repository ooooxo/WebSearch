using System.Text.Json.Serialization;

namespace WebSearch.Application.Models;

public sealed record ScrapeRequest(
    string Url,
    [property: JsonPropertyName("query")] string? Query = null);

public sealed record ScrapeResponse(
    string? Content,
    string Source,
    bool CacheHit,
    bool Success);
