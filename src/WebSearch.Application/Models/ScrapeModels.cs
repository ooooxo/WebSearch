namespace WebSearch.Application.Models;

public sealed record ScrapeRequest(string Url);

public sealed record ScrapeResponse(
    string? Content,
    string Source,
    bool CacheHit,
    bool Success);
