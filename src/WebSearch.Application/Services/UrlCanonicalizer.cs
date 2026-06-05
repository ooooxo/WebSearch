using System.Text;

namespace WebSearch.Application.Services;

public static class UrlCanonicalizer
{
    public static string Canonicalize(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            throw new ArgumentException("URL must be absolute.", nameof(url));
        }

        var scheme = uri.Scheme.ToLowerInvariant();
        var host = uri.Host.ToLowerInvariant();
        var port = uri.IsDefaultPort ? -1 : uri.Port;

        var path = uri.AbsolutePath;
        if (path.Length > 1 && path.EndsWith('/'))
        {
            path = path.TrimEnd('/');
        }

        var query = CanonicalizeQuery(uri.Query);
        var builder = new StringBuilder();
        builder.Append(scheme).Append("://").Append(host);

        if (port > 0)
        {
            builder.Append(':').Append(port);
        }

        builder.Append(path);

        if (!string.IsNullOrEmpty(query))
        {
            builder.Append('?').Append(query);
        }

        return builder.ToString();
    }

    private static string CanonicalizeQuery(string query)
    {
        if (string.IsNullOrEmpty(query))
        {
            return string.Empty;
        }

        var trimmed = query.TrimStart('?');
        if (string.IsNullOrEmpty(trimmed))
        {
            return string.Empty;
        }

        var pairs = trimmed
            .Split('&', StringSplitOptions.RemoveEmptyEntries)
            .Select(ParsePair)
            .OrderBy(p => p.Key, StringComparer.Ordinal)
            .ThenBy(p => p.Value, StringComparer.Ordinal)
            .Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value)}");

        return string.Join('&', pairs);
    }

    private static (string Key, string Value) ParsePair(string segment)
    {
        var index = segment.IndexOf('=');
        if (index < 0)
        {
            return (Uri.UnescapeDataString(segment), string.Empty);
        }

        var key = Uri.UnescapeDataString(segment[..index]);
        var value = Uri.UnescapeDataString(segment[(index + 1)..]);
        return (key, value);
    }
}
