namespace WebSearch.Application.Options;

public sealed class Crawl4AiOptions
{
    public const string SectionName = "Crawl4Ai";

    public string BaseUrl { get; set; } = "http://localhost:8001";
}
