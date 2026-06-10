using WebSearch.Application.Abstractions;

namespace WebSearch.Application.Services;

public sealed class NullRequestLogService : IRequestLogService
{
    public Task LogSearchAsync(string query, string normalizedQuery, string source, int resultCount,
        long durationMs, bool cacheHit, CancellationToken cancellationToken = default)
        => Task.CompletedTask;

    public Task LogScrapeAsync(string url, string source, bool success, int contentLength,
        long durationMs, bool cacheHit, CancellationToken cancellationToken = default)
        => Task.CompletedTask;
}
