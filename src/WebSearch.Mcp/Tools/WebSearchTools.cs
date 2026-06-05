using System.ComponentModel;
using System.Text.Json;
using ModelContextProtocol.Server;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;

namespace WebSearch.Mcp.Tools;

[McpServerToolType]
public sealed class WebSearchTools
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

    [McpServerTool(Name = "web_scrape"), Description("Scrape a URL and return page content as markdown.")]
    public static async Task<string> WebScrape(
        IScrapeService scrapeService,
        [Description("The absolute URL to scrape.")] string url,
        CancellationToken cancellationToken = default)
    {
        var response = await scrapeService.ScrapeAsync(new ScrapeRequest(url), cancellationToken);
        return JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true });
    }
}
