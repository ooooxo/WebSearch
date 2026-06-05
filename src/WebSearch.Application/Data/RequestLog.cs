namespace WebSearch.Application.Data;

public sealed class RequestLog
{
    public long Id { get; set; }
    public required string Endpoint { get; set; }
    public required string QueryOrUrl { get; set; }
    public string? Source { get; set; }
    public long DurationMs { get; set; }
    public bool CacheHit { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
