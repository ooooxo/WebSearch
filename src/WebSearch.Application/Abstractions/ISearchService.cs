using WebSearch.Application.Models;

namespace WebSearch.Application.Abstractions;

public interface ISearchService
{
    Task<SearchResponse> SearchAsync(SearchRequest request, CancellationToken cancellationToken = default);
}
