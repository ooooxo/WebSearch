namespace WebSearch.Application.Options;

public sealed class SearXngOptions
{
    public const string SectionName = "SearXng";

    public string BaseUrl { get; set; } = "http://localhost:8080";
}
