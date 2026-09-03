using System.Runtime.InteropServices;

namespace TextPolisher.Capture;

/// <summary>
/// Synthesizes keystrokes via SendInput and waits for physical modifier keys to
/// be released, mirroring the macOS KeyboardSimulator behavior.
/// </summary>
public static class InputSimulator
{
    private const ushort VK_CONTROL = 0x11;
    private const ushort VK_MENU = 0x12;    // Alt
    private const ushort VK_SHIFT = 0x10;
    private const ushort VK_LWIN = 0x5B;
    private const ushort VK_RWIN = 0x5C;
    private const ushort VK_C = 0x43;
    private const ushort VK_V = 0x56;

    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;

    public static void SendCtrlC() => SendCtrlChord(VK_C);

    public static void SendCtrlV() => SendCtrlChord(VK_V);

    private static void SendCtrlChord(ushort key)
    {
        var inputs = new[]
        {
            KeyInput(VK_CONTROL, keyUp: false),
            KeyInput(key, keyUp: false),
            KeyInput(key, keyUp: true),
            KeyInput(VK_CONTROL, keyUp: true),
        };
        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
    }

    /// <summary>
    /// Blocks (briefly) until Ctrl/Alt/Shift/Win are physically released, so a
    /// synthesized chord is not merged with the modifiers the user is still
    /// holding from the triggering hotkey.
    /// </summary>
    public static void WaitForModifiersReleased(int timeoutMs = 1000)
    {
        int waited = 0;
        while (waited < timeoutMs && AnyModifierDown())
        {
            Thread.Sleep(15);
            waited += 15;
        }
    }

    private static bool AnyModifierDown()
    {
        return IsDown(VK_CONTROL) || IsDown(VK_MENU) || IsDown(VK_SHIFT)
               || IsDown(VK_LWIN) || IsDown(VK_RWIN);
    }

    private static bool IsDown(ushort vk) => (GetAsyncKeyState(vk) & 0x8000) != 0;

    private static INPUT KeyInput(ushort vk, bool keyUp) => new()
    {
        type = INPUT_KEYBOARD,
        u = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = vk,
                wScan = 0,
                dwFlags = keyUp ? KEYEVENTF_KEYUP : 0,
                time = 0,
                dwExtraInfo = IntPtr.Zero,
            },
        },
    };

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }
}
