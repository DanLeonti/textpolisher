namespace TextPolisher.Engine;

/// <summary>Polish modes. Guidance strings are ported verbatim from the macOS app.</summary>
public enum Tone
{
    FixGrammar,
    Professional,
    Friendly,
    Concise,
}

public static class ToneExtensions
{
    public static string StorageKey(this Tone tone) => tone switch
    {
        Tone.FixGrammar => "fixGrammar",
        Tone.Professional => "professional",
        Tone.Friendly => "friendly",
        Tone.Concise => "concise",
        _ => "fixGrammar",
    };

    public static Tone FromStorageKey(string? key) => key switch
    {
        "professional" => Tone.Professional,
        "friendly" => Tone.Friendly,
        "concise" => Tone.Concise,
        _ => Tone.FixGrammar,
    };

    public static string Title(this Tone tone) => tone switch
    {
        Tone.FixGrammar => "Fix Grammar",
        Tone.Professional => "Professional",
        Tone.Friendly => "Friendly",
        Tone.Concise => "Concise",
        _ => "Fix Grammar",
    };

    public static string Guidance(this Tone tone) => tone switch
    {
        Tone.FixGrammar =>
            "Fix spelling, grammar, and punctuation only. Preserve the original meaning, tone, and wording as closely as possible and avoid rephrasing that is not required for correctness. If the text is already correct, return it unchanged.",
        Tone.Professional =>
            "Rewrite the text so it reads clearly and professionally, suitable for a workplace chat message. Keep it natural and human, not stiff or formal to the point of sounding robotic. Always produce a polished rewrite in this style, even when the original is already grammatically correct \u2014 for example, turn a terse fragment like \"need help with cursor limit increase\" into a complete, professional sentence.",
        Tone.Friendly =>
            "Rewrite the text so it sounds warm, friendly, and approachable while staying clear and to the point. Always produce a rewrite in this style, even when the original is already grammatically correct.",
        Tone.Concise =>
            "Rewrite the text to be as clear and concise as possible, removing filler while keeping every important detail. Always produce a tightened rewrite in this style, even when the original is already grammatically correct.",
        _ => "",
    };
}
