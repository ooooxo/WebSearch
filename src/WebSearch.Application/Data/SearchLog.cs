namespace WebSearch.Application.Data;

public sealed class SearchLog
{
    public long Id { get; set; }
    public required string Query { get; set; }
    public required string NormalizedQuery { get; set; }
    public required string Source { get; set; }
    public int ResultCount { get; set; }
    public bool CacheHit { get; set; }
    public long DurationMs { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
