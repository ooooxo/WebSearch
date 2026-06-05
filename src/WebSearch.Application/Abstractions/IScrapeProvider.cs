namespace WebSearch.Application.Abstractions;

public interface IScrapeProvider
{
    string Name { get; }
    bool IsConfigured { get; }
    Task<string?> ScrapeAsync(string url, CancellationToken cancellationToken = default);
}
