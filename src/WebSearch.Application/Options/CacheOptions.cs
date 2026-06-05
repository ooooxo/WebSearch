namespace WebSearch.Application.Options;

public sealed class CacheOptions
{
    public const string SectionName = "Cache";

    public int SearchTtlSeconds { get; set; } = 7200;
    public int ScrapeTtlSeconds { get; set; } = 86400;
}
