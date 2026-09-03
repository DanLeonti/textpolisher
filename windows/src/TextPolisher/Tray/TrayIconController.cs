using System.IO;
using System.Windows;
using System.Windows.Controls;
using Hardcodet.Wpf.TaskbarNotification;
using TextPolisher.Engine;
using TextPolisher.Preferences;
using TextPolisher.Settings;

namespace TextPolisher.Tray;

/// <summary>
/// System-tray icon and dynamic context menu (macOS MenuBarController equivalent).
/// </summary>
public sealed class TrayIconController : IDisposable
{
    private static readonly string[] SuggestedModels =
    {
        "qwen2.5:3b", "llama3.2", "llama3.2:1b", "phi3.5",
    };

    private readonly AppSettings _settings;
    private readonly PolishCoordinator _coordinator;
    private readonly EngineProvider _engineProvider;

    private TaskbarIcon? _tray;
    private ShortcutsWindow? _shortcutsWindow;

    public event EventHandler? QuitRequested;

    public TrayIconController(AppSettings settings, PolishCoordinator coordinator, EngineProvider engineProvider)
    {
        _settings = settings;
        _coordinator = coordinator;
        _engineProvider = engineProvider;
    }

    public void Initialize()
    {
        _tray = new TaskbarIcon
        {
            ToolTipText = "TextPolisher",
            Icon = LoadIcon(),
        };

        var menu = new ContextMenu();
        menu.Opened += (_, _) => RebuildMenu(menu);
        _tray.ContextMenu = menu;
        RebuildMenu(menu);

        _coordinator.NotificationRequested += (_, n) => ShowNotification(n.Title, n.Message);
    }

    public void SetBusy(bool busy)
    {
        RunOnUi(() =>
        {
            if (_tray is not null)
            {
                _tray.ToolTipText = busy ? "TextPolisher - polishing..." : "TextPolisher";
            }
        });
    }

    private void RebuildMenu(ContextMenu menu)
    {
        menu.Items.Clear();

        menu.Items.Add(MenuItem("Polish Selected Text", $"({_settings.PolishSelectionHotkey.DisplayString})",
            (_, _) => _coordinator.PolishFromHotKey()));
        menu.Items.Add(MenuItem("Polish && Replace Now", $"({_settings.PolishInstantHotkey.DisplayString})",
            (_, _) => _coordinator.PolishInstant()));
        menu.Items.Add(MenuItem("Polish Clipboard Text", null,
            (_, _) => _coordinator.PolishClipboard()));

        menu.Items.Add(new Separator());
        menu.Items.Add(BuildModelMenu());
        menu.Items.Add(BuildToneMenu());

        menu.Items.Add(new Separator());
        menu.Items.Add(MenuItem("Shortcuts...", null, (_, _) => OpenShortcuts()));
        menu.Items.Add(MenuItem("Model Status...", null, (_, _) => _ = ShowModelStatusAsync()));

        var startup = new MenuItem { Header = "Start on Login", IsCheckable = true, IsChecked = _settings.StartOnLogin };
        startup.Click += (_, _) => _settings.SetStartOnLogin(startup.IsChecked);
        menu.Items.Add(startup);

        menu.Items.Add(new Separator());
        menu.Items.Add(MenuItem("Quit TextPolisher", null, (_, _) => QuitRequested?.Invoke(this, EventArgs.Empty)));
    }

    private MenuItem BuildModelMenu()
    {
        var root = new MenuItem { Header = "Model" };
        var models = new List<string>(SuggestedModels);
        if (!models.Contains(_settings.OllamaModel))
        {
            models.Insert(0, _settings.OllamaModel);
        }

        foreach (var model in models)
        {
            var item = new MenuItem
            {
                Header = model,
                IsCheckable = true,
                IsChecked = model == _settings.OllamaModel,
            };
            string captured = model;
            item.Click += (_, _) => _settings.SetOllamaModel(captured);
            root.Items.Add(item);
        }
        return root;
    }

    private MenuItem BuildToneMenu()
    {
        var root = new MenuItem { Header = "Default Tone" };
        foreach (var tone in new[] { Tone.FixGrammar, Tone.Professional, Tone.Friendly, Tone.Concise })
        {
            var item = new MenuItem
            {
                Header = tone.Title(),
                IsCheckable = true,
                IsChecked = tone == _settings.DefaultTone,
            };
            Tone captured = tone;
            item.Click += (_, _) => _settings.SetDefaultTone(captured);
            root.Items.Add(item);
        }
        return root;
    }

    private void OpenShortcuts()
    {
        if (_shortcutsWindow is { IsVisible: true })
        {
            _shortcutsWindow.Activate();
            return;
        }

        _shortcutsWindow = new ShortcutsWindow(_settings);
        _shortcutsWindow.Closed += (_, _) => _shortcutsWindow = null;
        _shortcutsWindow.Show();
        _shortcutsWindow.Activate();
    }

    private async Task ShowModelStatusAsync()
    {
        var engine = _engineProvider.CurrentEngine();
        bool available = await engine.IsAvailableAsync().ConfigureAwait(false);
        string message;
        if (!available)
        {
            message = "The Ollama server is not reachable. Make sure Ollama is installed and running.";
        }
        else
        {
            var models = await engine.ListModelsAsync().ConfigureAwait(false);
            bool present = models.Any(m => m.Equals(_settings.OllamaModel, StringComparison.OrdinalIgnoreCase)
                                           || m.StartsWith(_settings.OllamaModel + ":", StringComparison.OrdinalIgnoreCase));
            message = present
                ? $"Ollama is running and the model '{_settings.OllamaModel}' is installed. You're all set."
                : $"Ollama is running, but the model '{_settings.OllamaModel}' is not installed yet.";
        }

        ShowNotification("Model Status", message);
    }

    private void ShowNotification(string title, string message)
    {
        RunOnUi(() => _tray?.ShowBalloonTip(title, message, BalloonIcon.Info));
    }

    private static System.Drawing.Icon? LoadIcon()
    {
        try
        {
            string path = Path.Combine(AppContext.BaseDirectory, "Assets", "app.ico");
            return File.Exists(path) ? new System.Drawing.Icon(path) : null;
        }
        catch
        {
            return null;
        }
    }

    private static MenuItem MenuItem(string header, string? hint, RoutedEventHandler onClick)
    {
        var item = new MenuItem { Header = header };
        if (hint is not null)
        {
            item.InputGestureText = hint;
        }
        item.Click += onClick;
        return item;
    }

    private static void RunOnUi(Action action)
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
        {
            action();
        }
        else
        {
            dispatcher.Invoke(action);
        }
    }

    public void Dispose()
    {
        _tray?.Dispose();
    }
}
