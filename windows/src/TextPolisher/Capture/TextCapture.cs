using System.Text;
using System.Windows.Automation;

namespace TextPolisher.Capture;

/// <summary>
/// Reads the currently selected text from the focused control using a two-tier
/// strategy: UI Automation TextPattern first (no clipboard side effects), then a
/// synthesized Ctrl+C with clipboard backup/restore as a universal fallback.
/// </summary>
public static class TextCapture
{
    /// <summary>Returns the selected text, or null if nothing could be read.</summary>
    public static string? CurrentSelection()
    {
        string? viaUia = AutomationSelection();
        if (!string.IsNullOrEmpty(viaUia))
        {
            return viaUia;
        }

        return CopySelection();
    }

    private static string? AutomationSelection()
    {
        try
        {
            var focused = AutomationElement.FocusedElement;
            if (focused is null)
            {
                return null;
            }

            if (focused.TryGetCurrentPattern(TextPattern.Pattern, out object patternObj)
                && patternObj is TextPattern textPattern)
            {
                var ranges = textPattern.GetSelection();
                if (ranges is { Length: > 0 })
                {
                    var sb = new StringBuilder();
                    foreach (var range in ranges)
                    {
                        sb.Append(range.GetText(-1));
                    }
                    string text = sb.ToString();
                    if (!string.IsNullOrEmpty(text))
                    {
                        return text;
                    }
                }
            }
        }
        catch
        {
            // UIA can throw for elevated/unsupported targets; fall through.
        }

        return null;
    }

    private static string? CopySelection()
    {
        InputSimulator.WaitForModifiersReleased();

        var backup = ClipboardHelper.Capture();
        string? previous = ClipboardHelper.GetText();
        ClipboardHelper.Clear();

        try
        {
            InputSimulator.SendCtrlC();

            // Poll for the clipboard to receive the copied selection.
            string? copied = null;
            for (int i = 0; i < 20; i++)
            {
                Thread.Sleep(25);
                string? current = ClipboardHelper.GetText();
                if (!string.IsNullOrEmpty(current) && current != previous)
                {
                    copied = current;
                    break;
                }
            }

            return string.IsNullOrEmpty(copied) ? null : copied;
        }
        finally
        {
            ClipboardHelper.Restore(backup);
        }
    }
}
