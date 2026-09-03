using System.Runtime.InteropServices;

namespace TextPolisher.Focus;

/// <summary>
/// Captures the foreground window at trigger time and restores focus to it
/// before replacing text, so the polished output goes back into the app the
/// user was actually working in (macOS AppFocusTracker equivalent).
/// </summary>
public static class ForegroundTracker
{
    public static IntPtr CaptureForegroundWindow() => GetForegroundWindow();

    /// <summary>
    /// Brings <paramref name="hwnd"/> back to the foreground and waits until it
    /// actually becomes foreground (polling), returning true on success.
    /// </summary>
    public static bool RestoreForeground(IntPtr hwnd, int timeoutMs = 1200)
    {
        if (hwnd == IntPtr.Zero || !IsWindow(hwnd))
        {
            return false;
        }

        if (IsIconic(hwnd))
        {
            ShowWindow(hwnd, SW_RESTORE);
        }

        // AttachThreadInput lets us call SetForegroundWindow reliably even when
        // our process is not the current foreground owner.
        uint targetThread = GetWindowThreadProcessId(hwnd, out _);
        uint currentThread = GetCurrentThreadId();

        bool attached = false;
        if (targetThread != currentThread)
        {
            attached = AttachThreadInput(currentThread, targetThread, true);
        }

        try
        {
            SetForegroundWindow(hwnd);
            BringWindowToTop(hwnd);
        }
        finally
        {
            if (attached)
            {
                AttachThreadInput(currentThread, targetThread, false);
            }
        }

        int waited = 0;
        while (waited < timeoutMs)
        {
            if (GetForegroundWindow() == hwnd)
            {
                return true;
            }
            Thread.Sleep(30);
            waited += 30;
        }

        return GetForegroundWindow() == hwnd;
    }

    private const int SW_RESTORE = 9;

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
}
