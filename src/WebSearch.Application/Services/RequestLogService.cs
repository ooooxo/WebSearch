using Microsoft.Extensions.Logging;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Data;

namespace WebSearch.Application.Services;

public sealed class RequestLogService(
    WebSearchDbContext db,
    ILogger<RequestLogService> logger) : IRequestLogService
{
    public async Task LogSearchAsync(
        string query,
        string normalizedQuery,
        string source,
        int resultCount,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default)
    {
        try
        {
            db.SearchLogs.Add(new SearchLog
            {
                Query = query,
                NormalizedQuery = normalizedQuery,
                Source = source,
                ResultCount = resultCount,
                DurationMs = durationMs,
                CacheHit = cacheHit,
                CreatedAt = DateTimeOffset.UtcNow,
            });
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to write search log for {Query}", query);
        }
    }

    public async Task LogScrapeAsync(
        string url,
        string source,
        bool success,
        int contentLength,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default)
    {
        try
        {
            db.ScrapeLogs.Add(new ScrapeLog
            {
                Url = url,
                Source = source,
                Success = success,
                ContentLength = contentLength,
                DurationMs = durationMs,
                CacheHit = cacheHit,
                CreatedAt = DateTimeOffset.UtcNow,
            });
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to write scrape log for {Url}", url);
        }
    }
}
