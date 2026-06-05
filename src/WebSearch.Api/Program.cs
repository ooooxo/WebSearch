using Microsoft.Extensions.Diagnostics.HealthChecks;
using WebSearch.Api.Endpoints;
using WebSearch.Api.Extensions;
using WebSearch.Application;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddWebSearchApplication(builder.Configuration);
builder.Services.AddOpenApi();

var includeDependencyHealthChecks =
    builder.Configuration.GetValue("HealthChecks:IncludeDependencies", true);

var healthChecks = builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy());

if (includeDependencyHealthChecks)
{
    var redisConnection = builder.Configuration["Redis:Connection"];
    if (!string.IsNullOrWhiteSpace(redisConnection))
    {
        healthChecks.AddRedis(redisConnection);
    }

    var postgresConnection = builder.Configuration.GetConnectionString("Postgres");
    if (!string.IsNullOrWhiteSpace(postgresConnection))
    {
        healthChecks.AddNpgSql(postgresConnection);
    }
}

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapHealthChecks("/health");
app.MapSearchEndpoints();
app.MapScrapeEndpoints();

await app.ApplyDatabaseMigrationsAsync();
app.Run();

public partial class Program;
