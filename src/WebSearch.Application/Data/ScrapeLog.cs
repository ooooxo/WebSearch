namespace WebSearch.Application.Data;

public sealed class ScrapeLog
{
    public long Id { get; set; }
    public required string Url { get; set; }
    public required string Source { get; set; }
    public bool Success { get; set; }
    public bool CacheHit { get; set; }
    public int ContentLength { get; set; }
    public long DurationMs { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
