namespace WebSearch.Application.Abstractions;

public interface IScrapeProvider
{
    string Name { get; }
    bool IsConfigured { get; }
    Task<string?> ScrapeAsync(string url, string? query = null, CancellationToken cancellationToken = default);
}
