using WebSearch.Application.Models;

namespace WebSearch.Application.Abstractions;

public interface ISearchDeepService
{
    Task<SearchDeepResponse> SearchDeepAsync(SearchDeepRequest request, CancellationToken cancellationToken = default);
}
