using WebSearch.Application.Services;

namespace WebSearch.Api.Tests;

public class NormalizerTests
{
    [Theory]
    [InlineData("asyncio最佳实践", "asyncio 最佳实践")]
    [InlineData("  asyncio   最佳实践  ", "asyncio 最佳实践")]
    [InlineData("asyncio 最佳实践", "asyncio 最佳实践")]
    [InlineData("ａｓｙｎｃｉｏ最佳实践", "asyncio 最佳实践")]
    public void QueryNormalizer_ProducesConsistentCacheInput(string input, string expected)
    {
        var normalized = QueryNormalizer.Normalize(input);
        Assert.Equal(expected, normalized);
        Assert.Equal(normalized, QueryNormalizer.Normalize(input));
    }

    [Fact]
    public void QueryNormalizer_EquivalentQueriesShareCacheKey()
    {
        var key1 = CacheKeyHelper.SearchKey(QueryNormalizer.Normalize("asyncio最佳实践"), 10);
        var key2 = CacheKeyHelper.SearchKey(QueryNormalizer.Normalize("  asyncio 最佳实践 "), 10);

        Assert.Equal(key1, key2);
    }

    [Theory]
    [InlineData("https://Example.COM/asyncio/", "https://example.com/asyncio")]
    [InlineData("https://example.com/asyncio?b=2&a=1", "https://example.com/asyncio?a=1&b=2")]
    [InlineData("https://example.com:443/asyncio", "https://example.com/asyncio")]
    public void UrlCanonicalizer_NormalizesEquivalentUrls(string input, string expected)
    {
        Assert.Equal(expected, UrlCanonicalizer.Canonicalize(input));
    }

    [Fact]
    public void UrlCanonicalizer_EquivalentUrlsShareCacheKey()
    {
        var url1 = UrlCanonicalizer.Canonicalize("https://example.com/asyncio/");
        var url2 = UrlCanonicalizer.Canonicalize("https://EXAMPLE.com/asyncio");

        Assert.Equal(CacheKeyHelper.ScrapeKey(url1), CacheKeyHelper.ScrapeKey(url2));
    }
}
