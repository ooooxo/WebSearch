using System.Diagnostics;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services;

public sealed class ScrapeService(
    IEnumerable<IScrapeProvider> providers,
    ICacheService cache,
    IRequestLogService requestLog,
    IOptions<CacheOptions> cacheOptions,
    ILogger<ScrapeService> logger) : IScrapeService
{
    private static readonly int MaxContentChars =
        int.TryParse(Environment.GetEnvironmentVariable("SCRAPE_MAX_CHARS"), out var v) && v > 0 ? v : 8000;

    private readonly IReadOnlyList<IScrapeProvider> _providers = providers.ToList();

    public async Task<ScrapeResponse> ScrapeAsync(ScrapeRequest request, CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();
        var canonicalUrl = UrlCanonicalizer.Canonicalize(request.Url);
        var cacheKey = CacheKeyHelper.ScrapeKey(canonicalUrl, request.Query);
        var cached = await cache.GetAsync<CachedScrapePayload>(cacheKey, cancellationToken);
        if (cached is not null)
        {
            sw.Stop();
            await requestLog.LogScrapeAsync(canonicalUrl, cached.Source, cached.Content is not null,
                cached.Content?.Length ?? 0, sw.ElapsedMilliseconds, true, cancellationToken);
            return new ScrapeResponse(cached.Content, cached.Source, true, cached.Content is not null);
        }

        string? content = null;
        string? source = null;

        foreach (var provider in _providers)
        {
            if (!provider.IsConfigured)
            {
                continue;
            }

            try
            {
                content = await provider.ScrapeAsync(canonicalUrl, request.Query, cancellationToken);
                if (!string.IsNullOrWhiteSpace(content))
                {
                    source = provider.Name;
                    break;
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Scrape provider {Provider} failed for {Url}", provider.Name, canonicalUrl);
            }
        }

        if (!string.IsNullOrWhiteSpace(content) && content.Length > MaxContentChars)
        {
            content = content[..MaxContentChars];
        }

        var success = !string.IsNullOrWhiteSpace(content);
        if (success && source is not null)
        {
            var ttl = TimeSpan.FromSeconds(cacheOptions.Value.ScrapeTtlSeconds);
            await cache.SetAsync(cacheKey, new CachedScrapePayload(content!, source), ttl, cancellationToken);
        }

        sw.Stop();
        await requestLog.LogScrapeAsync(canonicalUrl, source ?? "none", success,
            content?.Length ?? 0, sw.ElapsedMilliseconds, false, cancellationToken);
        logger.LogInformation(
            "Scrape completed for {Url} via {Source} in {Ms}ms",
            canonicalUrl, source ?? "none", sw.ElapsedMilliseconds);

        return new ScrapeResponse(content, source ?? "none", false, success);
    }

    private sealed record CachedScrapePayload(string Content, string Source);
}
