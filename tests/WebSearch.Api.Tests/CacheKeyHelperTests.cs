using WebSearch.Application.Services;

namespace WebSearch.Api.Tests;

public class CacheKeyHelperTests
{
    [Fact]
    public void SearchKey_IsDeterministic()
    {
        var key1 = CacheKeyHelper.SearchKey("aspnet core", 10);
        var key2 = CacheKeyHelper.SearchKey("aspnet core", 10);
        var key3 = CacheKeyHelper.SearchKey("aspnet core", 5);

        Assert.Equal(key1, key2);
        Assert.NotEqual(key1, key3);
        Assert.StartsWith("search:", key1);
    }

    [Fact]
    public void ScrapeKey_IsDeterministic()
    {
        var key1 = CacheKeyHelper.ScrapeKey("https://example.com");
        var key2 = CacheKeyHelper.ScrapeKey("https://example.com");

        Assert.Equal(key1, key2);
        Assert.StartsWith("scrape:", key1);
    }
}
