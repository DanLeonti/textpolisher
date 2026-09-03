using System.Windows;

namespace TextPolisher.Capture;

/// <summary>
/// Clipboard read/write with snapshot + restore so capture/replace never
/// permanently clobbers the user's clipboard (macOS Pasteboard equivalent).
/// All access is marshaled to the WPF UI (STA) thread and retried, because the
/// clipboard is a shared, frequently-locked resource.
/// </summary>
public static class ClipboardHelper
{
    private const int RetryCount = 8;
    private const int RetryDelayMs = 40;

    public sealed class Snapshot
    {
        internal readonly Dictionary<string, object> Data = new();
        internal bool Captured;
    }

    public static string? GetText()
    {
        return OnUiThread(() =>
        {
            for (int i = 0; i < RetryCount; i++)
            {
                try
                {
                    return Clipboard.ContainsText() ? Clipboard.GetText() : null;
                }
                catch
                {
                    Thread.Sleep(RetryDelayMs);
                }
            }
            return null;
        });
    }

    public static void SetText(string text)
    {
        OnUiThread(() =>
        {
            for (int i = 0; i < RetryCount; i++)
            {
                try
                {
                    Clipboard.SetText(text);
                    return true;
                }
                catch
                {
                    Thread.Sleep(RetryDelayMs);
                }
            }
            return false;
        });
    }

    public static void Clear()
    {
        OnUiThread(() =>
        {
            for (int i = 0; i < RetryCount; i++)
            {
                try
                {
                    Clipboard.Clear();
                    return true;
                }
                catch
                {
                    Thread.Sleep(RetryDelayMs);
                }
            }
            return false;
        });
    }

    public static Snapshot Capture()
    {
        return OnUiThread(() =>
        {
            var snapshot = new Snapshot();
            for (int i = 0; i < RetryCount; i++)
            {
                try
                {
                    var data = Clipboard.GetDataObject();
                    if (data is null)
                    {
                        snapshot.Captured = true;
                        return snapshot;
                    }

                    foreach (var format in data.GetFormats())
                    {
                        try
                        {
                            var value = data.GetData(format);
                            if (value is not null)
                            {
                                snapshot.Data[format] = value;
                            }
                        }
                        catch
                        {
                            // Some formats cannot be marshaled; skip them.
                        }
                    }

                    snapshot.Captured = true;
                    return snapshot;
                }
                catch
                {
                    Thread.Sleep(RetryDelayMs);
                }
            }
            return snapshot;
        });
    }

    public static void Restore(Snapshot snapshot)
    {
        if (!snapshot.Captured)
        {
            return;
        }

        OnUiThread(() =>
        {
            for (int i = 0; i < RetryCount; i++)
            {
                try
                {
                    if (snapshot.Data.Count == 0)
                    {
                        Clipboard.Clear();
                        return true;
                    }

                    var obj = new DataObject();
                    foreach (var kvp in snapshot.Data)
                    {
                        obj.SetData(kvp.Key, kvp.Value);
                    }
                    Clipboard.SetDataObject(obj, copy: true);
                    return true;
                }
                catch
                {
                    Thread.Sleep(RetryDelayMs);
                }
            }
            return false;
        });
    }

    private static T OnUiThread<T>(Func<T> func)
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
        {
            return func();
        }
        return dispatcher.Invoke(func);
    }
}
