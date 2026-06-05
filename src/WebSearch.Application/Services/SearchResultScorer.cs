namespace WebSearch.Application.Services;

public sealed class SearchResultScoreInput
{
    public required string Title { get; init; }
    public required string Url { get; init; }
    public string Snippet { get; init; } = string.Empty;
    public required IReadOnlyList<string> Engines { get; init; }
    public required IReadOnlyList<int> Positions { get; init; }
}

public static class SearchResultScorer
{
    public static float Score(SearchResultScoreInput result, string query)
    {
        var score = 0f;
        var engineCount = Math.Max(result.Engines.Count, 1);
        score += Math.Min(engineCount / 5f, 1f) * 0.35f;

        var positions = result.Positions.Count > 0 ? result.Positions : [10];
        var avgPos = (float)positions.Average();
        score += (1f / Math.Max(avgPos, 1f)) * 0.25f;

        var terms = query.ToLowerInvariant()
            .Split([' ', '\t'], StringSplitOptions.RemoveEmptyEntries);
        if (terms.Length > 0)
        {
            var title = result.Title.ToLowerInvariant();
            var snippet = result.Snippet.ToLowerInvariant();
            var titleHits = terms.Count(t => title.Contains(t, StringComparison.Ordinal)) / (float)terms.Length;
            var snippetHits = terms.Count(t => snippet.Contains(t, StringComparison.Ordinal)) / (float)terms.Length;
            score += (titleHits * 0.7f + snippetHits * 0.3f) * 0.20f;
        }

        score += DomainAuthority(result.Url) * 0.15f;
        score += Math.Min(result.Snippet.Length / 200f, 1f) * 0.05f;

        return score;
    }

    public static float DomainAuthority(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            return 0.5f;
        }

        var domain = uri.Host.ToLowerInvariant();
        if (domain.Contains("github.com", StringComparison.Ordinal)) return 1.0f;
        if (domain.Contains("stackoverflow.com", StringComparison.Ordinal)) return 1.0f;
        if (domain.Contains("wikipedia.org", StringComparison.Ordinal)) return 0.9f;
        if (domain.Contains("arxiv.org", StringComparison.Ordinal)) return 0.9f;
        if (domain.EndsWith(".edu", StringComparison.Ordinal)) return 0.8f;
        if (domain.EndsWith(".gov", StringComparison.Ordinal)) return 0.8f;
        if (domain.Contains("docs.", StringComparison.Ordinal)) return 0.8f;
        if (domain.Contains("medium.com", StringComparison.Ordinal)) return 0.5f;
        if (domain.Contains("reddit.com", StringComparison.Ordinal)) return 0.4f;
        return 0.5f;
    }
}
