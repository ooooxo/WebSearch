using WebSearch.Application.Services;

namespace WebSearch.Api.Tests;

public class SearchResultScorerTests
{
    [Fact]
    public void Score_GithubResult_RanksHigherThanUnknown()
    {
        var query = "asyncio tutorial";
        var github = SearchResultScorer.Score(new SearchResultScoreInput
        {
            Title = "Asyncio tutorial on GitHub",
            Url = "https://github.com/python/asyncio",
            Snippet = new string('x', 200),
            Engines = ["google", "bing", "duckduckgo"],
            Positions = [1, 2, 3],
        }, query);

        var unknown = SearchResultScorer.Score(new SearchResultScoreInput
        {
            Title = "random blog",
            Url = "https://random-blog.example.com/post",
            Snippet = "short",
            Engines = ["google"],
            Positions = [8],
        }, query);

        Assert.True(github > unknown);
        Assert.True(github > 0.4f);
    }

    [Fact]
    public void DomainAuthority_RecognizesTrustedDomains()
    {
        Assert.Equal(1.0f, SearchResultScorer.DomainAuthority("https://github.com/a/b"));
        Assert.Equal(0.8f, SearchResultScorer.DomainAuthority("https://docs.python.org/3/"));
    }
}
