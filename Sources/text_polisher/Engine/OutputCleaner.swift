import Foundation

/// Strips conversational preambles and wrapping quotes that models sometimes add
/// despite instructions (e.g. "Sure, here is the rewritten message:").
enum OutputCleaner {
    private static let preamblePatterns = [
        // "Sure, here is the rewritten message:", "Here's the polished text:", etc.
        "(?i)^\\s*(sure|certainly|of course|okay|ok|got it|absolutely|no problem)?[\\s,!.\\-]*here\\s*('s| is| are)?\\b[^:\\n]*:\\s*",
        // "I've rewritten the message:", "I have polished it as follows:"
        "(?i)^\\s*(sure|certainly|of course|okay|ok)?[\\s,!.\\-]*i\\s*('ve| have)\\s+(rewritten|polished|revised|updated|improved)\\b[^:\\n]*:\\s*",
        // "The rewritten message:", "Polished version:"
        "(?i)^\\s*(the\\s+)?(rewritten|polished|revised|updated|improved)\\s+(message|text|version)\\b[^:\\n]*:\\s*",
        // A standalone leading interjection line followed by a blank line.
        "(?i)^\\s*(sure|certainly|of course|okay|absolutely|got it|no problem)[!.,]*\\s*\\n+",
    ]

    static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove any <draft> / </draft> delimiter tags the model may echo back
        // from the prompt.
        text = text.replacingOccurrences(
            of: "(?i)</?draft>", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var didStrip = true
        while didStrip {
            didStrip = false
            for pattern in preamblePatterns {
                if let range = text.range(of: pattern, options: .regularExpression) {
                    text.removeSubrange(range)
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    didStrip = true
                }
            }
        }

        return stripWrappingQuotes(text)
    }

    private static func stripWrappingQuotes(_ text: String) -> String {
        guard text.count >= 2 else { return text }
        let pairs: [(Character, Character)] = [
            ("\"", "\""), ("'", "'"), ("\u{201C}", "\u{201D}"), ("\u{2018}", "\u{2019}"), ("`", "`"),
        ]
        for (open, close) in pairs where text.first == open && text.last == close {
            return String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}
