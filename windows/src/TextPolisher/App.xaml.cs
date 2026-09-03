using System.Threading;
using System.Windows;
using TextPolisher.Engine;
using TextPolisher.Hotkeys;
using TextPolisher.Ollama;
using TextPolisher.Settings;
using TextPolisher.Tray;

namespace TextPolisher;

/// <summary>
/// Composition root. TextPolisher runs as a background tray application with no
/// main window (ShutdownMode = OnExplicitShutdown). It wires up settings, the
/// Ollama engine, global hotkeys, the tray menu, and first-run model setup.
/// </summary>
public partial class App : Application
{
    private static Mutex? _singleInstanceMutex;

    private AppSettings _settings = null!;
    private EngineProvider _engineProvider = null!;
    private PolishCoordinator _coordinator = null!;
    private HotKeyManager _hotKeys = null!;
    private TrayIconController _tray = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Single-instance guard.
        _singleInstanceMutex = new Mutex(initiallyOwned: true, "TextPolisher.SingleInstance", out bool isNew);
        if (!isNew)
        {
            MessageBox.Show("TextPolisher is already running (check the system tray).",
                "TextPolisher", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        _settings = AppSettings.Load();

        _engineProvider = new EngineProvider(_settings);
        _coordinator = new PolishCoordinator(_settings, _engineProvider);

        _hotKeys = new HotKeyManager();
        RegisterHotKeys();
        _settings.ShortcutsChanged += (_, _) => RegisterHotKeys();

        _tray = new TrayIconController(_settings, _coordinator, _engineProvider);
        _tray.QuitRequested += (_, _) => Shutdown();
        _tray.Initialize();

        _coordinator.BusyChanged += (_, busy) => _tray.SetBusy(busy);

        // Ensure Ollama + default model are ready (first-run downloads the model
        // with a progress window). Runs in the background so the tray is
        // responsive immediately.
        _ = OllamaBootstrap.EnsureReadyAsync(_settings);
    }

    private void RegisterHotKeys()
    {
        _hotKeys.UnregisterAll();
        _hotKeys.Register(_settings.PolishSelectionHotkey, () => _coordinator.PolishFromHotKey());
        _hotKeys.Register(_settings.PolishInstantHotkey, () => _coordinator.PolishInstant());
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _hotKeys?.Dispose();
        _tray?.Dispose();
        _singleInstanceMutex?.ReleaseMutex();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
