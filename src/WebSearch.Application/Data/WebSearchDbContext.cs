using Microsoft.EntityFrameworkCore;

namespace WebSearch.Application.Data;

public sealed class WebSearchDbContext(DbContextOptions<WebSearchDbContext> options) : DbContext(options)
{
    public DbSet<RequestLog> RequestLogs => Set<RequestLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<RequestLog>(entity =>
        {
            entity.ToTable("request_logs");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Endpoint).HasColumnName("endpoint").HasMaxLength(32).IsRequired();
            entity.Property(e => e.QueryOrUrl).HasColumnName("query_or_url").IsRequired();
            entity.Property(e => e.Source).HasColumnName("source").HasMaxLength(32);
            entity.Property(e => e.DurationMs).HasColumnName("duration_ms");
            entity.Property(e => e.CacheHit).HasColumnName("cache_hit");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.HasIndex(e => e.CreatedAt);
        });
    }
}
