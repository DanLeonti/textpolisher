using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Win32;
using TextPolisher.Engine;
using TextPolisher.Hotkeys;

namespace TextPolisher.Settings;

/// <summary>
/// Persistent preferences stored as JSON under %AppData%\TextPolisher\settings.json.
/// Mirrors the macOS Settings/EngineProvider defaults.
/// </summary>
public sealed class AppSettings
{
    public const string DefaultOllamaBaseUrl = "http://127.0.0.1:11434";
    public const string DefaultOllamaModel = "qwen2.5:3b";

    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "TextPolisher";

    private static readonly string SettingsDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TextPolisher");

    private static readonly string SettingsPath = Path.Combine(SettingsDirectory, "settings.json");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    /// <summary>Raised when any preference changes.</summary>
    public event EventHandler? Changed;

    /// <summary>Raised when either global hotkey changes (App re-registers them).</summary>
    public event EventHandler? ShortcutsChanged;

    public string OllamaBaseUrl { get; private set; } = DefaultOllamaBaseUrl;
    public string OllamaModel { get; private set; } = DefaultOllamaModel;
    public Tone DefaultTone { get; private set; } = Tone.FixGrammar;
    public bool StartOnLogin { get; private set; }

    public KeyboardShortcut PolishSelectionHotkey { get; private set; } =
        new(KeyboardShortcut.VK_P, HotkeyModifiers.Control | HotkeyModifiers.Alt);

    public KeyboardShortcut PolishInstantHotkey { get; private set; } =
        new(KeyboardShortcut.VK_P, HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift);

    public static KeyboardShortcut DefaultSelectionHotkey =>
        new(KeyboardShortcut.VK_P, HotkeyModifiers.Control | HotkeyModifiers.Alt);

    public static KeyboardShortcut DefaultInstantHotkey =>
        new(KeyboardShortcut.VK_P, HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift);

    public static AppSettings Load()
    {
        var settings = new AppSettings();
        try
        {
            if (File.Exists(SettingsPath))
            {
                var data = JsonSerializer.Deserialize<SettingsData>(File.ReadAllText(SettingsPath));
                if (data is not null)
                {
                    settings.Apply(data);
                }
            }
        }
        catch
        {
            // Corrupt or unreadable settings fall back to defaults.
        }

        // Reflect the actual registry state for start-on-login.
        settings.StartOnLogin = settings.IsRegisteredForStartup();
        return settings;
    }

    public void SetOllamaModel(string model)
    {
        if (model == OllamaModel) return;
        OllamaModel = model;
        Persist(shortcutsChanged: false);
    }

    public void SetOllamaBaseUrl(string url)
    {
        if (url == OllamaBaseUrl) return;
        OllamaBaseUrl = url;
        Persist(shortcutsChanged: false);
    }

    public void SetDefaultTone(Tone tone)
    {
        if (tone == DefaultTone) return;
        DefaultTone = tone;
        Persist(shortcutsChanged: false);
    }

    public void SetHotkeys(KeyboardShortcut selection, KeyboardShortcut instant)
    {
        PolishSelectionHotkey = selection;
        PolishInstantHotkey = instant;
        Persist(shortcutsChanged: true);
    }

    public void SetStartOnLogin(bool enabled)
    {
        if (enabled == StartOnLogin) return;
        StartOnLogin = enabled;
        ApplyStartupRegistration(enabled);
        Persist(shortcutsChanged: false);
    }

    private void Apply(SettingsData data)
    {
        if (!string.IsNullOrWhiteSpace(data.OllamaBaseUrl)) OllamaBaseUrl = data.OllamaBaseUrl!;
        if (!string.IsNullOrWhiteSpace(data.OllamaModel)) OllamaModel = data.OllamaModel!;
        DefaultTone = ToneExtensions.FromStorageKey(data.DefaultTone);

        if (data.SelectionVirtualKey != 0)
        {
            PolishSelectionHotkey = new KeyboardShortcut(
                data.SelectionVirtualKey, (HotkeyModifiers)data.SelectionModifiers);
        }
        if (data.InstantVirtualKey != 0)
        {
            PolishInstantHotkey = new KeyboardShortcut(
                data.InstantVirtualKey, (HotkeyModifiers)data.InstantModifiers);
        }
    }

    private void Persist(bool shortcutsChanged)
    {
        Save();
        Changed?.Invoke(this, EventArgs.Empty);
        if (shortcutsChanged)
        {
            ShortcutsChanged?.Invoke(this, EventArgs.Empty);
        }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(SettingsDirectory);
            var data = new SettingsData
            {
                OllamaBaseUrl = OllamaBaseUrl,
                OllamaModel = OllamaModel,
                DefaultTone = DefaultTone.StorageKey(),
                SelectionVirtualKey = PolishSelectionHotkey.VirtualKey,
                SelectionModifiers = (uint)PolishSelectionHotkey.Modifiers,
                InstantVirtualKey = PolishInstantHotkey.VirtualKey,
                InstantModifiers = (uint)PolishInstantHotkey.Modifiers,
            };
            File.WriteAllText(SettingsPath, JsonSerializer.Serialize(data, JsonOptions));
        }
        catch
        {
            // Best-effort; ignore write failures.
        }
    }

    private bool IsRegisteredForStartup()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
            return key?.GetValue(RunValueName) is not null;
        }
        catch
        {
            return false;
        }
    }

    private void ApplyStartupRegistration(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);
            if (key is null) return;
            if (enabled)
            {
                string exe = Environment.ProcessPath ?? Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;
                if (exe.Length > 0)
                {
                    key.SetValue(RunValueName, $"\"{exe}\"");
                }
            }
            else
            {
                key.DeleteValue(RunValueName, throwOnMissingValue: false);
            }
        }
        catch
        {
            // Ignore registry failures (e.g. locked-down environments).
        }
    }

    private sealed class SettingsData
    {
        public string? OllamaBaseUrl { get; set; }
        public string? OllamaModel { get; set; }
        public string? DefaultTone { get; set; }
        public uint SelectionVirtualKey { get; set; }
        public uint SelectionModifiers { get; set; }
        public uint InstantVirtualKey { get; set; }
        public uint InstantModifiers { get; set; }
    }
}
