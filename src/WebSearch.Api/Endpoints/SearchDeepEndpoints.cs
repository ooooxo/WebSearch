using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;

namespace WebSearch.Api.Endpoints;

public static class SearchDeepEndpoints
{
    public static IEndpointRouteBuilder MapSearchDeepEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/search").WithTags("Search");

        group.MapPost("/deep", async (
            SearchDeepRequest request,
            ISearchDeepService searchDeepService,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Query))
            {
                return Results.BadRequest(new { error = "query is required" });
            }

            var maxResults = request.MaxResults is > 0 and <= 50 ? request.MaxResults : 10;
            var maxScrape = request.MaxScrape is >= 0 and <= 10 ? request.MaxScrape : 10;
            var minScore = request.MinScore is >= 0 and <= 1 ? request.MinScore : 0.4f;

            var response = await searchDeepService.SearchDeepAsync(
                new SearchDeepRequest(request.Query, maxResults, maxScrape, minScore),
                cancellationToken);

            return Results.Ok(response);
        })
        .WithName("SearchDeep")
        .WithSummary("Search the web and scrape results with score above min_score");

        return app;
    }
}
