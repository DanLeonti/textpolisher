namespace TextPolisher.Engine;

/// <summary>
/// A text-polishing backend. Implementations stream the cumulative polished text
/// so the UI can update progressively.
/// </summary>
public interface IPolishEngine
{
    string DisplayName { get; }

    Task<bool> IsAvailableAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Streams the cumulative (not delta) polished text. Callers should apply
    /// <see cref="OutputCleaner"/> to each yielded value.
    /// </summary>
    IAsyncEnumerable<string> StreamAsync(string text, Tone tone, CancellationToken cancellationToken = default);
}
