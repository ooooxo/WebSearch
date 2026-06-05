namespace WebSearch.Application.Services;

internal sealed class MergedSearchResult
{
    public required string Title { get; init; }
    public required string Url { get; init; }
    public string Snippet { get; set; } = string.Empty;
    public List<string> Engines { get; } = [];
    public List<int> Positions { get; } = [];
}

internal static class SearchResultMerger
{
    public static IReadOnlyList<MergedSearchResult> Merge(
        IEnumerable<SearXngRawResult> rawResults,
        int maxResults)
    {
        var byUrl = new Dictionary<string, MergedSearchResult>(StringComparer.OrdinalIgnoreCase);
        var position = 1;

        foreach (var raw in rawResults)
        {
            if (string.IsNullOrWhiteSpace(raw.Url))
            {
                position++;
                continue;
            }

            string canonical;
            try
            {
                canonical = UrlCanonicalizer.Canonicalize(raw.Url);
            }
            catch
            {
                canonical = raw.Url;
            }

            if (!byUrl.TryGetValue(canonical, out var merged))
            {
                merged = new MergedSearchResult
                {
                    Title = raw.Title,
                    Url = canonical,
                    Snippet = raw.Content ?? string.Empty,
                };
                byUrl[canonical] = merged;
            }

            if (string.IsNullOrWhiteSpace(merged.Snippet) && !string.IsNullOrWhiteSpace(raw.Content))
            {
                merged.Snippet = raw.Content!;
            }

            if (raw.Engines is { Count: > 0 })
            {
                foreach (var engine in raw.Engines)
                {
                    if (!merged.Engines.Contains(engine, StringComparer.OrdinalIgnoreCase))
                    {
                        merged.Engines.Add(engine);
                    }
                }
            }
            else if (!string.IsNullOrWhiteSpace(raw.Engine)
                     && !merged.Engines.Contains(raw.Engine, StringComparer.OrdinalIgnoreCase))
            {
                merged.Engines.Add(raw.Engine);
            }

            if (raw.Positions is { Count: > 0 })
            {
                merged.Positions.AddRange(raw.Positions);
            }
            else
            {
                merged.Positions.Add(raw.Position ?? position);
            }

            position++;
        }

        return byUrl.Values.Take(maxResults * 2).ToList();
    }
}

internal sealed class SearXngRawResult
{
    public string Title { get; init; } = string.Empty;
    public string Url { get; init; } = string.Empty;
    public string? Content { get; init; }
    public string? Engine { get; init; }
    public List<string>? Engines { get; init; }
    public List<int>? Positions { get; init; }
    public int? Position { get; init; }
}
