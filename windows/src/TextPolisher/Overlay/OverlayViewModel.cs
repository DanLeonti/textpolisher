using System.ComponentModel;
using System.Runtime.CompilerServices;
using TextPolisher.Engine;

namespace TextPolisher.Overlay;

/// <summary>
/// State and streaming logic for the preview overlay. Applies OutputCleaner to
/// each partial, exactly like the macOS OverlayViewModel.
/// </summary>
public sealed class OverlayViewModel : INotifyPropertyChanged
{
    private readonly EngineProvider _engineProvider;
    private CancellationTokenSource? _cts;

    public OverlayViewModel(string originalText, Tone initialTone, EngineProvider engineProvider)
    {
        _originalText = originalText;
        _selectedTone = initialTone;
        _engineProvider = engineProvider;
    }

    public event EventHandler<string>? Accepted;
    public event EventHandler? Cancelled;

    private string _originalText;
    public string OriginalText
    {
        get => _originalText;
        private set => Set(ref _originalText, value);
    }

    private string _polishedText = string.Empty;
    public string PolishedText
    {
        get => _polishedText;
        private set { Set(ref _polishedText, value); Raise(nameof(CanAccept)); }
    }

    private bool _isWorking;
    public bool IsWorking
    {
        get => _isWorking;
        private set { Set(ref _isWorking, value); Raise(nameof(CanAccept)); }
    }

    private string? _errorMessage;
    public string? ErrorMessage
    {
        get => _errorMessage;
        private set { Set(ref _errorMessage, value); Raise(nameof(HasError)); Raise(nameof(CanAccept)); }
    }

    private string _engineName = "Ollama (local)";
    public string EngineName
    {
        get => _engineName;
        private set => Set(ref _engineName, value);
    }

    private Tone _selectedTone;
    public Tone SelectedTone
    {
        get => _selectedTone;
        private set => Set(ref _selectedTone, value);
    }

    public bool HasError => !string.IsNullOrEmpty(ErrorMessage);

    public bool CanAccept => !IsWorking && !HasError && !string.IsNullOrWhiteSpace(PolishedText);

    public IReadOnlyList<Tone> Tones { get; } = new[]
    {
        Tone.FixGrammar, Tone.Professional, Tone.Friendly, Tone.Concise,
    };

    public void Start() => _ = RunAsync();

    public void Regenerate() => _ = RunAsync();

    public void SelectTone(Tone tone)
    {
        if (tone == SelectedTone && (IsWorking || CanAccept))
        {
            return;
        }
        SelectedTone = tone;
        _ = RunAsync();
    }

    public void Accept()
    {
        if (!CanAccept)
        {
            return;
        }
        Cancel(quiet: true);
        Accepted?.Invoke(this, PolishedText);
    }

    public void Cancel() => Cancel(quiet: false);

    private void Cancel(bool quiet)
    {
        _cts?.Cancel();
        if (!quiet)
        {
            Cancelled?.Invoke(this, EventArgs.Empty);
        }
    }

    private async Task RunAsync()
    {
        _cts?.Cancel();
        var cts = new CancellationTokenSource();
        _cts = cts;

        IsWorking = true;
        ErrorMessage = null;
        PolishedText = string.Empty;

        var engine = _engineProvider.CurrentEngine();
        EngineName = engine.DisplayName;

        try
        {
            await foreach (var partial in engine.StreamAsync(OriginalText, SelectedTone, cts.Token))
            {
                if (cts.IsCancellationRequested)
                {
                    return;
                }
                PolishedText = OutputCleaner.Clean(partial);
            }
        }
        catch (OperationCanceledException)
        {
            // Superseded by a newer run or cancelled by the user.
        }
        catch (EngineException ex)
        {
            ErrorMessage = Describe(ex);
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
        }
        finally
        {
            if (_cts == cts)
            {
                IsWorking = false;
            }
        }
    }

    private static string Describe(EngineException ex) => ex.Kind switch
    {
        EngineErrorKind.Empty => "The model returned an empty result. Try Regenerate.",
        EngineErrorKind.Http => ex.Message,
        _ => ex.Message,
    };

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }
        field = value;
        Raise(name);
    }

    private void Raise(string? name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
