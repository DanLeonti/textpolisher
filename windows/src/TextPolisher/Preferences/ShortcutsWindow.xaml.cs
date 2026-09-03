using System.Windows;
using System.Windows.Input;
using TextPolisher.Hotkeys;
using TextPolisher.Settings;

namespace TextPolisher.Preferences;

public partial class ShortcutsWindow : Window
{
    private readonly AppSettings _settings;

    private KeyboardShortcut _selection;
    private KeyboardShortcut _instant;

    private enum Recording { None, Selection, Instant }
    private Recording _recording = Recording.None;

    public ShortcutsWindow(AppSettings settings)
    {
        InitializeComponent();
        _settings = settings;
        _selection = settings.PolishSelectionHotkey;
        _instant = settings.PolishInstantHotkey;
        RefreshLabels();

        PreviewKeyDown += OnPreviewKeyDown;
    }

    private void RefreshLabels()
    {
        SelectionButton.Content = _recording == Recording.Selection ? "Press keys..." : _selection.DisplayString;
        InstantButton.Content = _recording == Recording.Instant ? "Press keys..." : _instant.DisplayString;
    }

    private void OnRecordSelection(object sender, RoutedEventArgs e)
    {
        _recording = Recording.Selection;
        RefreshLabels();
    }

    private void OnRecordInstant(object sender, RoutedEventArgs e)
    {
        _recording = Recording.Instant;
        RefreshLabels();
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (_recording == Recording.None)
        {
            return;
        }

        Key key = e.Key == Key.System ? e.SystemKey : e.Key;

        // Ignore standalone modifier presses; wait for a real key.
        if (IsModifierKey(key))
        {
            return;
        }

        e.Handled = true;

        if (key == Key.Escape)
        {
            _recording = Recording.None;
            RefreshLabels();
            return;
        }

        var mods = HotkeyModifiers.None;
        var current = Keyboard.Modifiers;
        if (current.HasFlag(ModifierKeys.Control)) mods |= HotkeyModifiers.Control;
        if (current.HasFlag(ModifierKeys.Alt)) mods |= HotkeyModifiers.Alt;
        if (current.HasFlag(ModifierKeys.Shift)) mods |= HotkeyModifiers.Shift;
        if (current.HasFlag(ModifierKeys.Windows)) mods |= HotkeyModifiers.Win;

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);
        var shortcut = new KeyboardShortcut(vk, mods);

        if (!shortcut.IsValid)
        {
            SystemSounds_Beep();
            return;
        }

        if (_recording == Recording.Selection)
        {
            _selection = shortcut;
        }
        else if (_recording == Recording.Instant)
        {
            _instant = shortcut;
        }

        _recording = Recording.None;
        RefreshLabels();
    }

    private static bool IsModifierKey(Key key) => key is
        Key.LeftCtrl or Key.RightCtrl or
        Key.LeftAlt or Key.RightAlt or
        Key.LeftShift or Key.RightShift or
        Key.LWin or Key.RWin or
        Key.System;

    private static void SystemSounds_Beep() => System.Media.SystemSounds.Beep.Play();

    private void OnRestoreDefaults(object sender, RoutedEventArgs e)
    {
        _selection = AppSettings.DefaultSelectionHotkey;
        _instant = AppSettings.DefaultInstantHotkey;
        _recording = Recording.None;
        RefreshLabels();
    }

    private void OnSave(object sender, RoutedEventArgs e)
    {
        _settings.SetHotkeys(_selection, _instant);
        Close();
    }
}
