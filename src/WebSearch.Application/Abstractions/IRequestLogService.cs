namespace WebSearch.Application.Abstractions;

public interface IRequestLogService
{
    Task LogAsync(
        string endpoint,
        string queryOrUrl,
        string? source,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default);
}
