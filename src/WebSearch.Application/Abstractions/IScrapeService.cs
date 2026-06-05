using WebSearch.Application.Models;

namespace WebSearch.Application.Abstractions;

public interface IScrapeService
{
    Task<ScrapeResponse> ScrapeAsync(ScrapeRequest request, CancellationToken cancellationToken = default);
}
