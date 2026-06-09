namespace WebSearch.Application.Options;

public sealed class CrawlSvcOptions
{
    public const string SectionName = "CrawlSvc";

    public string BaseUrl { get; set; } = "http://localhost:8001";
}
