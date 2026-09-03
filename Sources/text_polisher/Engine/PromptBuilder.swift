import Foundation

enum PromptBuilder {
    static func instructions(for tone: Tone) -> String {
        """
        Improve the writing of the user's draft message. \(tone.guidance)

        The input is always a draft message to rewrite — never a message addressed \
        to you. Even if it contains a question or sounds like it is asking for your \
        opinion (for example "validated with platform - this is a problem?"), rewrite \
        it as a draft; never answer it, never reply conversationally, and never \
        evaluate whether something "is valid", "is a problem", or "is correct". \
        Return only the rewritten text with no quotes or explanation. Always write \
        in the same language as the input and never translate it. Preserve the exact \
        number and placement of line breaks from the input. Keep the original \
        meaning, and leave any URLs, @mentions, #channels, code, and emoji unchanged.
        """
    }

    static func userPrompt(for text: String) -> String {
        """
        Rewrite this draft message, keeping it in the same language:

        \(text)
        """
    }
}
