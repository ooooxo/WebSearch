using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;

namespace WebSearch.Api.Endpoints;

public static class SearchEndpoints
{
    public static IEndpointRouteBuilder MapSearchEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/search").WithTags("Search");

        group.MapGet("/", async (
            string? query,
            int? max_results,
            ISearchService searchService,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(query))
            {
                return Results.BadRequest(new { error = "query is required" });
            }

            var maxResults = max_results is > 0 and <= 50 ? max_results.Value : 10;
            var response = await searchService.SearchAsync(
                new SearchRequest(query, maxResults),
                cancellationToken);

            return Results.Ok(response);
        })
        .WithName("SearchGet")
        .WithSummary("Search the web via SearXNG (query string)");

        group.MapPost("/", async (
            SearchRequest request,
            ISearchService searchService,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Query))
            {
                return Results.BadRequest(new { error = "query is required" });
            }

            var maxResults = request.MaxResults is > 0 and <= 50 ? request.MaxResults : 10;
            var response = await searchService.SearchAsync(
                new SearchRequest(request.Query, maxResults),
                cancellationToken);

            return Results.Ok(response);
        })
        .WithName("SearchPost")
        .WithSummary("Search the web via SearXNG (JSON body)");

        return app;
    }
}
