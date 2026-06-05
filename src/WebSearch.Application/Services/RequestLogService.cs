using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Data;

namespace WebSearch.Application.Services;

public sealed class RequestLogService(
    WebSearchDbContext db,
    ILogger<RequestLogService> logger) : IRequestLogService
{
    public async Task LogAsync(
        string endpoint,
        string queryOrUrl,
        string? source,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default)
    {
        try
        {
            db.RequestLogs.Add(new RequestLog
            {
                Endpoint = endpoint,
                QueryOrUrl = queryOrUrl,
                Source = source,
                DurationMs = durationMs,
                CacheHit = cacheHit,
                CreatedAt = DateTimeOffset.UtcNow,
            });
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to write request log for {Endpoint}", endpoint);
        }
    }
}
