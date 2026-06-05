using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services.ScrapeProviders;

public sealed class FirecrawlScrapeProvider(
    IHttpClientFactory httpClientFactory,
    IOptions<FirecrawlOptions> options) : IScrapeProvider
{
    public string Name => "firecrawl";
    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.ApiKey);

    public async Task<string?> ScrapeAsync(string url, CancellationToken cancellationToken = default)
    {
        if (!IsConfigured)
        {
            return null;
        }

        var client = httpClientFactory.CreateClient("firecrawl");
        var response = await client.PostAsJsonAsync(
            "/v1/scrape",
            new { url, formats = new[] { "markdown" } },
            cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        var payload = await response.Content.ReadFromJsonAsync<FirecrawlResponse>(cancellationToken);
        return payload?.Data?.Markdown;
    }

    private sealed class FirecrawlResponse
    {
        [JsonPropertyName("data")]
        public FirecrawlData? Data { get; set; }
    }

    private sealed class FirecrawlData
    {
        [JsonPropertyName("markdown")]
        public string? Markdown { get; set; }
    }
}
