using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using ModelContextProtocol.Server;
using WebSearch.Api.Endpoints;
using WebSearch.Api.Extensions;
using WebSearch.Application;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddWebSearchApplication(builder.Configuration);
builder.Services.AddOpenApi();

// MCP Server — HTTP/SSE transport (remote clients use /mcp endpoint)
builder.Services
    .AddMcpServer()
    .WithHttpTransport()
    .WithToolsFromAssembly();

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

// 存活探针
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Name == "self",
});

// 就绪探针（含 Redis + PostgreSQL）
app.MapHealthChecks("/health");

app.MapSearchEndpoints();
app.MapSearchDeepEndpoints();
app.MapScrapeEndpoints();

// MCP SSE endpoint — Claude Desktop / Cursor 远程连接用
app.MapMcp("/mcp");

await app.ApplyDatabaseMigrationsAsync();
app.Run();

public partial class Program;
