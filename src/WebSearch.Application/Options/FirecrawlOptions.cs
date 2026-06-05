namespace WebSearch.Application.Options;

public sealed class FirecrawlOptions
{
    public const string SectionName = "Firecrawl";

    public string ApiKey { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = "https://api.firecrawl.dev";
}
