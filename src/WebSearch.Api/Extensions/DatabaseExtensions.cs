using Microsoft.EntityFrameworkCore;
using WebSearch.Application.Data;

namespace WebSearch.Api.Extensions;

public static class DatabaseExtensions
{
    public static async Task ApplyDatabaseMigrationsAsync(this WebApplication app)
    {
        if (!app.Configuration.GetValue<bool>("Database:ApplyMigrationsOnStartup"))
        {
            return;
        }

        var logger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Database");

        try
        {
            await using var scope = app.Services.CreateAsyncScope();
            var db = scope.ServiceProvider.GetService<WebSearchDbContext>();
            if (db is null)
            {
                return;
            }

            await db.Database.MigrateAsync();
            logger.LogInformation("Database migrations applied.");
        }
        catch (Exception ex)
        {
            logger.LogError(
                ex,
                "Database migration failed. Check ConnectionStrings:Postgres in container env. API will start but /health may return 503.");
        }
    }
}
