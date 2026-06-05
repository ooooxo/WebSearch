using Microsoft.AspNetCore.Mvc.Testing;

namespace WebSearch.Api.Tests;

public class SearchEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public SearchEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.UseSetting("HealthChecks:IncludeDependencies", "false");
            builder.UseSetting("ConnectionStrings:Postgres", "");
        }).CreateClient();
    }

    [Fact]
    public async Task Search_WithoutQuery_ReturnsBadRequest()
    {
        var response = await _client.GetAsync("/search?query=");

        Assert.Equal(System.Net.HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Health_ReturnsOk()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
    }
}
