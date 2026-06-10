using Microsoft.EntityFrameworkCore;

namespace WebSearch.Application.Data;

public sealed class WebSearchDbContext(DbContextOptions<WebSearchDbContext> options) : DbContext(options)
{
    public DbSet<SearchLog> SearchLogs => Set<SearchLog>();
    public DbSet<ScrapeLog> ScrapeLogs => Set<ScrapeLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SearchLog>(entity =>
        {
            entity.ToTable("search_logs");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Query).HasColumnName("query").IsRequired();
            entity.Property(e => e.NormalizedQuery).HasColumnName("normalized_query").IsRequired();
            entity.Property(e => e.Source).HasColumnName("source").HasMaxLength(32).IsRequired();
            entity.Property(e => e.ResultCount).HasColumnName("result_count");
            entity.Property(e => e.CacheHit).HasColumnName("cache_hit");
            entity.Property(e => e.DurationMs).HasColumnName("duration_ms");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => new { e.Source, e.CreatedAt });
        });

        modelBuilder.Entity<ScrapeLog>(entity =>
        {
            entity.ToTable("scrape_logs");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Url).HasColumnName("url").IsRequired();
            entity.Property(e => e.Source).HasColumnName("source").HasMaxLength(32).IsRequired();
            entity.Property(e => e.Success).HasColumnName("success");
            entity.Property(e => e.CacheHit).HasColumnName("cache_hit");
            entity.Property(e => e.ContentLength).HasColumnName("content_length");
            entity.Property(e => e.DurationMs).HasColumnName("duration_ms");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.HasIndex(e => new { e.Url, e.CreatedAt });
            entity.HasIndex(e => new { e.Source, e.CreatedAt });
        });
    }
}
