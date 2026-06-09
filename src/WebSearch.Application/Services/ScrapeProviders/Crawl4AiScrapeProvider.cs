using System.Net.Http.Json;
using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services.ScrapeProviders;

public sealed class Crawl4AiScrapeProvider(
    IHttpClientFactory httpClientFactory,
    IOptions<Crawl4AiOptions> options) : IScrapeProvider
{
    public string Name => "crawl4ai";
    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.BaseUrl);

    public async Task<string?> ScrapeAsync(
        string url,
        string? query = null,
        CancellationToken cancellationToken = default)
    {
        var client = httpClientFactory.CreateClient("crawl4ai");
        var response = await client.PostAsJsonAsync("/crawl", new { url, query }, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        var payload = await response.Content.ReadFromJsonAsync<Crawl4AiResponse>(cancellationToken);
        return payload is { Success: true } ? payload.Content : null;
    }

    private sealed record Crawl4AiResponse(string? Content, bool Success);
}
