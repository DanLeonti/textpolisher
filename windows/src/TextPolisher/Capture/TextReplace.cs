using System.Windows.Automation;

namespace TextPolisher.Capture;

/// <summary>
/// Replaces the current selection with polished text. Prefers UI Automation
/// ValuePattern.SetValue when it is safe (the whole control value equals the
/// captured selection), otherwise falls back to a synthesized Ctrl+V paste with
/// clipboard backup/restore.
/// </summary>
public static class TextReplace
{
    /// <summary>
    /// Replaces the selection with <paramref name="newText"/>.
    /// <paramref name="originalText"/> is the text that was captured, used to
    /// decide whether a whole-value SetValue is safe.
    /// </summary>
    public static void Replace(string originalText, string newText)
    {
        if (TryAutomationReplace(originalText, newText))
        {
            return;
        }

        PasteReplace(newText);
    }

    private static bool TryAutomationReplace(string originalText, string newText)
    {
        try
        {
            var focused = AutomationElement.FocusedElement;
            if (focused is null)
            {
                return false;
            }

            if (!focused.TryGetCurrentPattern(ValuePattern.Pattern, out object patternObj)
                || patternObj is not ValuePattern valuePattern)
            {
                return false;
            }

            if (valuePattern.Current.IsReadOnly)
            {
                return false;
            }

            // Only safe when the entire control content is the selection we
            // captured; otherwise SetValue would wipe unselected text.
            string current = valuePattern.Current.Value ?? string.Empty;
            if (current.Trim() != originalText.Trim())
            {
                return false;
            }

            valuePattern.SetValue(newText);

            // Verify the change actually took effect (Electron/web fields often
            // report success but ignore it).
            string after = valuePattern.Current.Value ?? string.Empty;
            return after.Trim() == newText.Trim();
        }
        catch
        {
            return false;
        }
    }

    private static void PasteReplace(string text)
    {
        var backup = ClipboardHelper.Capture();
        ClipboardHelper.SetText(text);

        try
        {
            InputSimulator.WaitForModifiersReleased();
            // Small settle delay so the target app has focus before the paste.
            Thread.Sleep(30);
            InputSimulator.SendCtrlV();
            // Give the target time to consume the clipboard before we restore it.
            Thread.Sleep(120);
        }
        finally
        {
            ClipboardHelper.Restore(backup);
        }
    }
}
