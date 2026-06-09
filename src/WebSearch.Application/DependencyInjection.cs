using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;
using WebSearch.Application.Abstractions;
using WebSearch.Application.Data;
using WebSearch.Application.Options;
using WebSearch.Application.Services;
using WebSearch.Application.Services.ScrapeProviders;

namespace WebSearch.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddWebSearchApplication(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<SearXngOptions>(configuration.GetSection(SearXngOptions.SectionName));
        services.Configure<CrawlSvcOptions>(configuration.GetSection(CrawlSvcOptions.SectionName));
        services.Configure<CacheOptions>(configuration.GetSection(CacheOptions.SectionName));
        services.Configure<FirecrawlOptions>(configuration.GetSection(FirecrawlOptions.SectionName));

        var redisConnection = configuration["Redis:Connection"] ?? "localhost:6379,abortConnect=false";
        if (!redisConnection.Contains("abortConnect", StringComparison.OrdinalIgnoreCase))
        {
            redisConnection += ",abortConnect=false";
        }

        services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(redisConnection));
        services.AddSingleton<ICacheService, RedisCacheService>();

        services.AddHttpClient("searxng", (sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<SearXngOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            client.Timeout = TimeSpan.FromSeconds(30);
        });

        services.AddHttpClient("crawl-svc", (sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<CrawlSvcOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            client.Timeout = TimeSpan.FromMinutes(2);
        });

        services.AddHttpClient("firecrawl", (sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<FirecrawlOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            client.DefaultRequestHeaders.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", options.ApiKey);
            client.Timeout = TimeSpan.FromMinutes(2);
        });

        var postgresConnection = configuration.GetConnectionString("Postgres");
        if (!string.IsNullOrWhiteSpace(postgresConnection))
        {
            services.AddDbContext<WebSearchDbContext>(options =>
                options.UseNpgsql(postgresConnection));
            services.AddScoped<IRequestLogService, RequestLogService>();
        }
        else
        {
            services.AddSingleton<IRequestLogService, NullRequestLogService>();
        }

        services.AddScoped<ISearchService, SearchService>();
        services.AddScoped<ISearchDeepService, SearchDeepService>();
        // Scrape provider chain: crawl-svc (free, local) → Firecrawl (paid fallback)
        services.AddScoped<IScrapeProvider, CrawlSvcScrapeProvider>();
        services.AddScoped<IScrapeProvider, FirecrawlScrapeProvider>();
        services.AddScoped<IScrapeService, ScrapeService>();

        return services;
    }
}
