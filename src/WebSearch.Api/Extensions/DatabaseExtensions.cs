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

        await using var scope = app.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetService<WebSearchDbContext>();
        if (db is null)
        {
            return;
        }

        await db.Database.MigrateAsync();
    }
}
