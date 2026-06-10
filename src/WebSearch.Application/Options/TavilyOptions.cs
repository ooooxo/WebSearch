namespace WebSearch.Application.Options;

public sealed class TavilyOptions
{
    public const string SectionName = "Tavily";

    public string? ApiKey { get; set; }
    public int MinResultCount { get; set; } = 4;
    public float MinAverageScore { get; set; } = 0.3f;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(ApiKey);
}
