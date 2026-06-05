using System.Security.Cryptography;
using System.Text;

namespace WebSearch.Application.Services;

internal static class CacheKeyHelper
{
    public static string SearchKey(string query, int maxResults) =>
        $"search:{Hash(query)}:{maxResults}";

    public static string ScrapeKey(string url) =>
        $"scrape:{Hash(url)}";

    private static string Hash(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
