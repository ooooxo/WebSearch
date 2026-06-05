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
    private readonly IReadOnlyList<IScrapeProvider> _providers = providers.ToList();

    public async Task<ScrapeResponse> ScrapeAsync(ScrapeRequest request, CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();
        var canonicalUrl = UrlCanonicalizer.Canonicalize(request.Url);
        var cacheKey = CacheKeyHelper.ScrapeKey(canonicalUrl);
        var cached = await cache.GetAsync<CachedScrapePayload>(cacheKey, cancellationToken);
        if (cached is not null)
        {
            sw.Stop();
            await requestLog.LogAsync("scrape", canonicalUrl, cached.Source, sw.ElapsedMilliseconds, true, cancellationToken);
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
                content = await provider.ScrapeAsync(canonicalUrl, cancellationToken);
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

        var success = !string.IsNullOrWhiteSpace(content);
        if (success && source is not null)
        {
            var ttl = TimeSpan.FromSeconds(cacheOptions.Value.ScrapeTtlSeconds);
            await cache.SetAsync(cacheKey, new CachedScrapePayload(content!, source), ttl, cancellationToken);
        }

        sw.Stop();
        await requestLog.LogAsync("scrape", canonicalUrl, source, sw.ElapsedMilliseconds, false, cancellationToken);
        logger.LogInformation(
            "Scrape completed for {Url} via {Source} in {Ms}ms",
            canonicalUrl,
            source ?? "none",
            sw.ElapsedMilliseconds);

        return new ScrapeResponse(content, source ?? "none", false, success);
    }

    private sealed record CachedScrapePayload(string Content, string Source);
}
