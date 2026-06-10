namespace WebSearch.Application.Abstractions;

public interface IRequestLogService
{
    Task LogSearchAsync(
        string query,
        string normalizedQuery,
        string source,
        int resultCount,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default);

    Task LogScrapeAsync(
        string url,
        string source,
        bool success,
        int contentLength,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default);
}
