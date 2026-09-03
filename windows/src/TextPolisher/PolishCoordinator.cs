using System.Windows;
using System.Windows.Threading;
using TextPolisher.Capture;
using TextPolisher.Engine;
using TextPolisher.Focus;
using TextPolisher.Overlay;
using TextPolisher.Settings;

namespace TextPolisher;

/// <summary>
/// Orchestrates capture -> polish -> replace, mirroring the macOS PolishCoordinator.
/// Capture/replace run on background threads; UI (overlay) runs on the dispatcher.
/// </summary>
public sealed class PolishCoordinator
{
    private readonly AppSettings _settings;
    private readonly EngineProvider _engineProvider;
    private readonly Dispatcher _dispatcher;

    private OverlayWindow? _overlay;

    public PolishCoordinator(AppSettings settings, EngineProvider engineProvider)
    {
        _settings = settings;
        _engineProvider = engineProvider;
        _dispatcher = Application.Current.Dispatcher;
    }

    /// <summary>Raised with true while an instant/replace operation is running.</summary>
    public event EventHandler<bool>? BusyChanged;

    /// <summary>Raised to surface a user-facing message (title, body) via the tray.</summary>
    public event EventHandler<(string Title, string Message)>? NotificationRequested;

    /// <summary>Hotkey / menu: capture selection and show the preview overlay.</summary>
    public void PolishFromHotKey()
    {
        IntPtr source = ForegroundTracker.CaptureForegroundWindow();
        Task.Run(() =>
        {
            string? text = TextCapture.CurrentSelection();
            _dispatcher.Invoke(() =>
            {
                if (string.IsNullOrWhiteSpace(text))
                {
                    Notify("Nothing to polish", "Select some text first, then try again.");
                    return;
                }
                ShowOverlayForSelection(text!, source);
            });
        });
    }

    /// <summary>Hotkey / menu: capture selection, polish with the default tone, replace in place.</summary>
    public void PolishInstant()
    {
        IntPtr source = ForegroundTracker.CaptureForegroundWindow();
        SetBusy(true);
        Task.Run(async () =>
        {
            try
            {
                string? text = TextCapture.CurrentSelection();
                if (string.IsNullOrWhiteSpace(text))
                {
                    Notify("Nothing to polish", "Select some text first, then try again.");
                    return;
                }

                string? result = await PolishToCompletionAsync(text!, _settings.DefaultTone).ConfigureAwait(false);
                if (string.IsNullOrWhiteSpace(result))
                {
                    return;
                }

                PerformReplace(source, text!, result!);
            }
            finally
            {
                SetBusy(false);
            }
        });
    }

    /// <summary>Menu: polish the clipboard text and copy the result back to the clipboard.</summary>
    public void PolishClipboard()
    {
        string? text = ClipboardHelper.GetText();
        if (string.IsNullOrWhiteSpace(text))
        {
            Notify("Clipboard is empty", "Copy some text first, then try again.");
            return;
        }

        ShowOverlayForClipboard(text!);
    }

    private void ShowOverlayForSelection(string text, IntPtr source)
    {
        var viewModel = new OverlayViewModel(text, _settings.DefaultTone, _engineProvider);
        viewModel.Accepted += (_, polished) =>
        {
            SetBusy(true);
            Task.Run(() =>
            {
                try { PerformReplace(source, text, polished); }
                finally { SetBusy(false); }
            });
        };
        ShowOverlay(viewModel);
    }

    private void ShowOverlayForClipboard(string text)
    {
        var viewModel = new OverlayViewModel(text, _settings.DefaultTone, _engineProvider);
        viewModel.Accepted += (_, polished) =>
        {
            ClipboardHelper.SetText(polished);
            Notify("Polished text copied", "The polished text is on your clipboard - paste it where you need it.");
        };
        ShowOverlay(viewModel);
    }

    private void ShowOverlay(OverlayViewModel viewModel)
    {
        _overlay?.Close();
        _overlay = new OverlayWindow(viewModel);
        _overlay.Closed += (_, _) => _overlay = null;
        _overlay.Show();
        _overlay.Activate();
    }

    private async Task<string?> PolishToCompletionAsync(string text, Tone tone)
    {
        var engine = _engineProvider.CurrentEngine();
        try
        {
            string result = string.Empty;
            await foreach (var partial in engine.StreamAsync(text, tone).ConfigureAwait(false))
            {
                result = OutputCleaner.Clean(partial);
            }

            if (string.IsNullOrWhiteSpace(result))
            {
                Notify("Nothing changed", "The model returned an empty result.");
                return null;
            }

            return result;
        }
        catch (EngineException ex)
        {
            Notify("Polish failed", ex.Message);
            return null;
        }
        catch (Exception ex)
        {
            Notify("Polish failed", ex.Message);
            return null;
        }
    }

    private void PerformReplace(IntPtr source, string original, string polished)
    {
        ForegroundTracker.RestoreForeground(source);
        // Let focus settle before injecting.
        Thread.Sleep(120);
        TextReplace.Replace(original, polished);
    }

    private void SetBusy(bool busy) => BusyChanged?.Invoke(this, busy);

    private void Notify(string title, string message) =>
        NotificationRequested?.Invoke(this, (title, message));
}
