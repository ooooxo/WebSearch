using WebSearch.Application.Abstractions;

namespace WebSearch.Application.Services;

public sealed class NullRequestLogService : IRequestLogService
{
    public Task LogAsync(
        string endpoint,
        string queryOrUrl,
        string? source,
        long durationMs,
        bool cacheHit,
        CancellationToken cancellationToken = default) =>
        Task.CompletedTask;
}
