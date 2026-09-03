using System.Text.RegularExpressions;

namespace TextPolisher.Engine;

/// <summary>
/// Strips conversational preambles and wrapping quotes that models sometimes add
/// despite instructions (e.g. "Sure, here is the rewritten message:").
/// Regexes ported verbatim from the macOS app.
/// </summary>
public static class OutputCleaner
{
    private static readonly Regex[] PreamblePatterns =
    {
        // "Sure, here is the rewritten message:", "Here's the polished text:", etc.
        new(@"(?i)^\s*(sure|certainly|of course|okay|ok|got it|absolutely|no problem)?[\s,!.\-]*here\s*('s| is| are)?\b[^:\n]*:\s*"),
        // "I've rewritten the message:", "I have polished it as follows:"
        new(@"(?i)^\s*(sure|certainly|of course|okay|ok)?[\s,!.\-]*i\s*('ve| have)\s+(rewritten|polished|revised|updated|improved)\b[^:\n]*:\s*"),
        // "The rewritten message:", "Polished version:"
        new(@"(?i)^\s*(the\s+)?(rewritten|polished|revised|updated|improved)\s+(message|text|version)\b[^:\n]*:\s*"),
        // A standalone leading interjection line followed by a blank line.
        new(@"(?i)^\s*(sure|certainly|of course|okay|absolutely|got it|no problem)[!.,]*\s*\n+"),
    };

    private static readonly Regex DraftTag = new(@"(?i)</?draft>");

    private static readonly (char Open, char Close)[] QuotePairs =
    {
        ('"', '"'), ('\'', '\''), ('\u201C', '\u201D'), ('\u2018', '\u2019'), ('`', '`'),
    };

    public static string Clean(string raw)
    {
        string text = raw.Trim();

        // Remove any <draft> / </draft> delimiter tags the model may echo back.
        text = DraftTag.Replace(text, string.Empty).Trim();

        bool didStrip = true;
        while (didStrip)
        {
            didStrip = false;
            foreach (var pattern in PreamblePatterns)
            {
                var match = pattern.Match(text);
                if (match.Success && match.Length > 0)
                {
                    text = text.Remove(match.Index, match.Length).Trim();
                    didStrip = true;
                }
            }
        }

        return StripWrappingQuotes(text);
    }

    private static string StripWrappingQuotes(string text)
    {
        if (text.Length < 2)
        {
            return text;
        }

        foreach (var (open, close) in QuotePairs)
        {
            if (text[0] == open && text[^1] == close)
            {
                return text[1..^1].Trim();
            }
        }

        return text;
    }
}
