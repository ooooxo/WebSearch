using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace WebSearch.Application.Services;

public static partial class QueryNormalizer
{
    private static readonly Regex CollapseWhitespace = WhitespacePattern();

    public static string Normalize(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return string.Empty;
        }

        var normalized = ToHalfWidth(query.Trim());
        normalized = CollapseWhitespace.Replace(normalized, " ");
        normalized = InsertLatinCjkSpaces(normalized);
        normalized = CollapseWhitespace.Replace(normalized, " ").Trim();

        return normalized;
    }

    private static string InsertLatinCjkSpaces(string input)
    {
        if (input.Length < 2)
        {
            return input;
        }

        var buffer = new StringBuilder(input.Length + 8);
        buffer.Append(input[0]);

        for (var i = 1; i < input.Length; i++)
        {
            var previous = input[i - 1];
            var current = input[i];

            if (ShouldInsertBoundarySpace(previous, current))
            {
                buffer.Append(' ');
            }

            buffer.Append(current);
        }

        return buffer.ToString();
    }

    private static bool ShouldInsertBoundarySpace(char previous, char current)
    {
        return (IsLatinAlphanumeric(previous) && IsCjk(current))
            || (IsCjk(previous) && IsLatinAlphanumeric(current));
    }

    private static bool IsLatinAlphanumeric(char ch) =>
        ch is (>= 'a' and <= 'z') or (>= 'A' and <= 'Z') or (>= '0' and <= '9');

    private static bool IsCjk(char ch)
    {
        var category = CharUnicodeInfo.GetUnicodeCategory(ch);
        return category is UnicodeCategory.OtherLetter
            && (ch >= '\u4E00' && ch <= '\u9FFF'
                || ch >= '\u3400' && ch <= '\u4DBF'
                || ch >= '\uF900' && ch <= '\uFAFF');
    }

    private static string ToHalfWidth(string input)
    {
        var buffer = new StringBuilder(input.Length);
        foreach (var ch in input)
        {
            buffer.Append(ch switch
            {
                '\u3000' => ' ',
                >= '\uFF01' and <= '\uFF5E' => (char)(ch - 0xFEE0),
                _ => ch,
            });
        }

        return buffer.ToString();
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespacePattern();
}
