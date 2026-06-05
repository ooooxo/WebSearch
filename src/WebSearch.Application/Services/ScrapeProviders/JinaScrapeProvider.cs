using Microsoft.Extensions.Options;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Options;

namespace WebSearch.Application.Services.ScrapeProviders;

public sealed class JinaScrapeProvider(
    IHttpClientFactory httpClientFactory,
    IOptions<JinaOptions> options) : IScrapeProvider
{
    public string Name => "jina";
    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.ApiKey);

    public async Task<string?> ScrapeAsync(string url, CancellationToken cancellationToken = default)
    {
        if (!IsConfigured)
        {
            return null;
        }

        var client = httpClientFactory.CreateClient("jina");
        var requestUri = $"/{url}";
        var response = await client.GetAsync(requestUri, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        return await response.Content.ReadAsStringAsync(cancellationToken);
    }
}
