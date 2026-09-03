namespace TextPolisher.Engine;

/// <summary>Error kinds a polish engine can surface, mirroring the macOS EngineError.</summary>
public enum EngineErrorKind
{
    Unavailable,
    Http,
    Empty,
}

public sealed class EngineException : Exception
{
    public EngineErrorKind Kind { get; }
    public int? StatusCode { get; }

    private EngineException(EngineErrorKind kind, string message, int? statusCode = null)
        : base(message)
    {
        Kind = kind;
        StatusCode = statusCode;
    }

    public static EngineException Unavailable(string reason) =>
        new(EngineErrorKind.Unavailable, reason);

    public static EngineException Http(int statusCode) =>
        new(EngineErrorKind.Http, $"The model server returned HTTP {statusCode}.", statusCode);

    public static EngineException Empty() =>
        new(EngineErrorKind.Empty, "The model returned an empty response.");
}
