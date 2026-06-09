using System.ComponentModel;
using System.Text.Json;
using ModelContextProtocol.Server;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;

namespace WebSearch.Api.McpTools;

[McpServerToolType]
public sealed class WebSearchMcpTools
{
    [McpServerTool(Name = "web_search"), Description("Search the web and return structured results.")]
    public static async Task<string> WebSearch(
        ISearchService searchService,
        [Description("The search query.")] string query,
        [Description("Maximum number of results (1-50).")] int max_results = 10,
        CancellationToken cancellationToken = default)
    {
        var maxResults = Math.Clamp(max_results, 1, 50);
        var response = await searchService.SearchAsync(new SearchRequest(query, maxResults), cancellationToken);
        return JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true });
    }

    [McpServerTool(Name = "web_search_deep"), Description("Search the web and scrape top result pages in one response.")]
    public static async Task<string> WebSearchDeep(
        ISearchDeepService searchDeepService,
        [Description("The search query.")] string query,
        [Description("Maximum search results (1-50).")] int max_results = 10,
        [Description("Max URLs to scrape among high-score results (0-10).")] int max_scrape = 10,
        [Description("Minimum relevance score (0-1) to trigger scrape.")] float min_score = 0.4f,
        CancellationToken cancellationToken = default)
    {
        var response = await searchDeepService.SearchDeepAsync(
            new SearchDeepRequest(
                query,
                Math.Clamp(max_results, 1, 50),
                Math.Clamp(max_scrape, 0, 10),
                Math.Clamp(min_score, 0f, 1f)),
            cancellationToken);
        return JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true });
    }

    [McpServerTool(Name = "web_scrape"), Description("Scrape a URL and return page content as markdown.")]
    public static async Task<string> WebScrape(
        IScrapeService scrapeService,
        [Description("The absolute URL to scrape.")] string url,
        CancellationToken cancellationToken = default)
    {
        var response = await scrapeService.ScrapeAsync(new ScrapeRequest(url, null), cancellationToken);
        return JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true });
    }
}
