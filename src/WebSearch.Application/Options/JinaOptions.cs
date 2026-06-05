namespace WebSearch.Application.Options;

public sealed class JinaOptions
{
    public const string SectionName = "Jina";

    public string ApiKey { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = "https://r.jina.ai";
}
