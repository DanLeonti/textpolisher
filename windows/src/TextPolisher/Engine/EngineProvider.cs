using TextPolisher.Settings;

namespace TextPolisher.Engine;

/// <summary>
/// Resolves the active polish engine from settings. On Windows the only backend
/// is Ollama (there is no Apple Foundation Models equivalent), but this keeps the
/// same seam as the macOS EngineProvider for future backends.
/// </summary>
public sealed class EngineProvider
{
    private readonly AppSettings _settings;

    public EngineProvider(AppSettings settings)
    {
        _settings = settings;
    }

    public OllamaEngine CurrentEngine() =>
        new(_settings.OllamaBaseUrl, _settings.OllamaModel);
}
