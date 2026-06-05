using WebSearch.Application.Abstractions;
using WebSearch.Application.Models;

namespace WebSearch.Api.Endpoints;

public static class ScrapeEndpoints
{
    public static IEndpointRouteBuilder MapScrapeEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/scrape").WithTags("Scrape");

        group.MapPost("/", async (
            ScrapeRequest request,
            IScrapeService scrapeService,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Url))
            {
                return Results.BadRequest(new { error = "url is required" });
            }

            if (!Uri.TryCreate(request.Url, UriKind.Absolute, out _))
            {
                return Results.BadRequest(new { error = "url must be an absolute URI" });
            }

            var response = await scrapeService.ScrapeAsync(request, cancellationToken);
            return Results.Ok(response);
        })
        .WithName("Scrape")
        .WithSummary("Scrape a URL to markdown with provider fallback");

        return app;
    }
}
