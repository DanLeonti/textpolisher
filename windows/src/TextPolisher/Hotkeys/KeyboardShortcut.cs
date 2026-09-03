namespace TextPolisher.Hotkeys;

/// <summary>Win32 RegisterHotKey modifier flags (fsModifiers).</summary>
[Flags]
public enum HotkeyModifiers : uint
{
    None = 0x0,
    Alt = 0x1,      // MOD_ALT
    Control = 0x2,  // MOD_CONTROL
    Shift = 0x4,    // MOD_SHIFT
    Win = 0x8,      // MOD_WIN
}

/// <summary>
/// A global hotkey definition: a Win32 virtual-key code plus modifier flags.
/// Requires at least one of Ctrl / Alt / Win (Shift alone is not a valid global
/// hotkey), mirroring the macOS validity rule.
/// </summary>
public sealed record KeyboardShortcut(uint VirtualKey, HotkeyModifiers Modifiers)
{
    // Common virtual-key codes.
    public const uint VK_P = 0x50;

    public bool IsValid =>
        VirtualKey != 0 &&
        (Modifiers & (HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Win)) != 0;

    public string DisplayString
    {
        get
        {
            var parts = new List<string>();
            if (Modifiers.HasFlag(HotkeyModifiers.Control)) parts.Add("Ctrl");
            if (Modifiers.HasFlag(HotkeyModifiers.Alt)) parts.Add("Alt");
            if (Modifiers.HasFlag(HotkeyModifiers.Shift)) parts.Add("Shift");
            if (Modifiers.HasFlag(HotkeyModifiers.Win)) parts.Add("Win");
            parts.Add(KeyName(VirtualKey));
            return string.Join("+", parts);
        }
    }

    public static string KeyName(uint vk)
    {
        // Letters A-Z
        if (vk >= 0x41 && vk <= 0x5A)
        {
            return ((char)vk).ToString();
        }
        // Digits 0-9
        if (vk >= 0x30 && vk <= 0x39)
        {
            return ((char)vk).ToString();
        }
        // Function keys F1-F24
        if (vk >= 0x70 && vk <= 0x87)
        {
            return "F" + (vk - 0x6F);
        }

        return vk switch
        {
            0x20 => "Space",
            0x0D => "Enter",
            0xBE => ".",
            0xBC => ",",
            0xBF => "/",
            0xDB => "[",
            0xDD => "]",
            _ => "0x" + vk.ToString("X2"),
        };
    }
}
