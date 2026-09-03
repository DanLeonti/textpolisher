using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace TextPolisher.Hotkeys;

/// <summary>
/// System-wide hotkeys via Win32 RegisterHotKey, dispatched through a hidden
/// message-only window (macOS Carbon HotKeyManager equivalent).
/// Must be constructed on the WPF UI thread.
/// </summary>
public sealed class HotKeyManager : IDisposable
{
    private const int WM_HOTKEY = 0x0312;
    private const uint MOD_NOREPEAT = 0x4000;

    private readonly HwndSource _source;
    private readonly Dictionary<int, Action> _handlers = new();
    private int _nextId = 1;

    public HotKeyManager()
    {
        var parameters = new HwndSourceParameters("TextPolisher.HotKeyWindow")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0,
            ExtendedWindowStyle = 0,
            ParentWindow = HWND_MESSAGE,
        };
        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);
    }

    public void Register(KeyboardShortcut shortcut, Action handler)
    {
        if (!shortcut.IsValid)
        {
            return;
        }

        int id = _nextId++;
        if (RegisterHotKey(_source.Handle, id, (uint)shortcut.Modifiers | MOD_NOREPEAT, shortcut.VirtualKey))
        {
            _handlers[id] = handler;
        }
    }

    public void UnregisterAll()
    {
        foreach (int id in _handlers.Keys)
        {
            UnregisterHotKey(_source.Handle, id);
        }
        _handlers.Clear();
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY)
        {
            int id = wParam.ToInt32();
            if (_handlers.TryGetValue(id, out var handler))
            {
                handled = true;
                // Dispatch async so the message pump is not blocked while we
                // capture/polish text.
                Application.Current?.Dispatcher.BeginInvoke(handler);
            }
        }

        return IntPtr.Zero;
    }

    public void Dispose()
    {
        UnregisterAll();
        _source.RemoveHook(WndProc);
        _source.Dispose();
    }

    private static readonly IntPtr HWND_MESSAGE = new(-3);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
