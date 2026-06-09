using System.Net.Http.Json;
using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services.ScrapeProviders;

public sealed class CrawlSvcScrapeProvider(
    IHttpClientFactory httpClientFactory,
    IOptions<CrawlSvcOptions> options) : IScrapeProvider
{
    public string Name => "crawl-svc";
    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.BaseUrl);

    public async Task<string?> ScrapeAsync(
        string url,
        string? query = null,
        CancellationToken cancellationToken = default)
    {
        var client = httpClientFactory.CreateClient("crawl-svc");
        var response = await client.PostAsJsonAsync("/crawl", new { url }, cancellationToken);
        if (!response.IsSuccessStatusCode)
            return null;

        var payload = await response.Content.ReadFromJsonAsync<CrawlSvcResponse>(cancellationToken);
        return payload is { Success: true } ? payload.Content : null;
    }

    private sealed record CrawlSvcResponse(string? Content, bool Success, string Source);
}
