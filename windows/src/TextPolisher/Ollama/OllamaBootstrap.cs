using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;
using TextPolisher.Engine;
using TextPolisher.Settings;
using TextPolisher.Setup;

namespace TextPolisher.Ollama;

/// <summary>
/// First-run readiness: makes sure the Ollama server is running and the default
/// model is downloaded. The model pull (large) shows a progress window.
/// </summary>
public static class OllamaBootstrap
{
    private static readonly HttpClient PullClient = new() { Timeout = Timeout.InfiniteTimeSpan };

    public static async Task EnsureReadyAsync(AppSettings settings)
    {
        try
        {
            string baseUrl = settings.OllamaBaseUrl.TrimEnd('/');
            var engine = new OllamaEngine(baseUrl, settings.OllamaModel);

            bool reachable = await engine.IsAvailableAsync().ConfigureAwait(false);
            if (!reachable)
            {
                string? exe = FindOllamaExe();
                if (exe is null)
                {
                    ShowMessage(
                        "Ollama is not installed. TextPolisher needs Ollama to run the local AI model.\n\n" +
                        "Reinstall using the TextPolisher installer (it installs Ollama automatically), " +
                        "or download it from https://ollama.com/download.",
                        "TextPolisher");
                    return;
                }

                TryStartServer(exe);
                reachable = await WaitForServerAsync(engine, TimeSpan.FromSeconds(30)).ConfigureAwait(false);
                if (!reachable)
                {
                    ShowMessage(
                        "Could not start the Ollama server automatically. Please start Ollama, then reopen TextPolisher.",
                        "TextPolisher");
                    return;
                }
            }

            if (await IsModelPresentAsync(engine, settings.OllamaModel).ConfigureAwait(false))
            {
                return;
            }

            await PullModelWithProgressAsync(baseUrl, settings.OllamaModel).ConfigureAwait(false);
        }
        catch
        {
            // Bootstrap is best-effort; failures surface later when polishing.
        }
    }

    private static async Task<bool> IsModelPresentAsync(OllamaEngine engine, string model)
    {
        var models = await engine.ListModelsAsync().ConfigureAwait(false);
        return models.Any(m =>
            m.Equals(model, StringComparison.OrdinalIgnoreCase) ||
            m.StartsWith(model + ":", StringComparison.OrdinalIgnoreCase) ||
            (!model.Contains(':') && m.StartsWith(model + ":", StringComparison.OrdinalIgnoreCase)));
    }

    private static async Task<bool> WaitForServerAsync(OllamaEngine engine, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (await engine.IsAvailableAsync().ConfigureAwait(false))
            {
                return true;
            }
            await Task.Delay(1000).ConfigureAwait(false);
        }
        return false;
    }

    private static string? FindOllamaExe()
    {
        // 1) Default per-user install location.
        string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string candidate = Path.Combine(localApp, "Programs", "Ollama", "ollama.exe");
        if (File.Exists(candidate))
        {
            return candidate;
        }

        // 2) Program Files (machine-wide install).
        foreach (var pf in new[]
                 {
                     Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                     Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                 })
        {
            string p = Path.Combine(pf, "Ollama", "ollama.exe");
            if (File.Exists(p))
            {
                return p;
            }
        }

        // 3) On PATH.
        string? path = Environment.GetEnvironmentVariable("PATH");
        if (path is not null)
        {
            foreach (var dir in path.Split(Path.PathSeparator))
            {
                try
                {
                    string p = Path.Combine(dir.Trim(), "ollama.exe");
                    if (File.Exists(p))
                    {
                        return p;
                    }
                }
                catch
                {
                    // Ignore malformed PATH entries.
                }
            }
        }

        return null;
    }

    private static void TryStartServer(string exe)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = exe,
                Arguments = "serve",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            Process.Start(psi);
        }
        catch
        {
            // The Ollama background service may already own the port; ignore.
        }
    }

    private static async Task PullModelWithProgressAsync(string baseUrl, string model)
    {
        var dispatcher = Application.Current?.Dispatcher;
        SetupWindow? window = null;

        if (dispatcher is not null)
        {
            await dispatcher.InvokeAsync(() =>
            {
                window = new SetupWindow();
                window.SetStatus($"Downloading model '{model}'...");
                window.SetProgress(null);
                window.Show();
                window.Activate();
            });
        }

        void Report(string status, double? pct, string detail)
        {
            if (dispatcher is null || window is null)
            {
                return;
            }
            dispatcher.InvokeAsync(() =>
            {
                window.SetStatus(status);
                window.SetProgress(pct);
                window.SetDetail(detail);
            });
        }

        try
        {
            var payload = JsonSerializer.Serialize(new PullRequest { Name = model, Stream = true });
            using var request = new HttpRequestMessage(HttpMethod.Post, $"{baseUrl}/api/pull")
            {
                Content = new StringContent(payload, Encoding.UTF8, "application/json"),
            };

            using var response = await PullClient.SendAsync(
                request, HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            await using var stream = await response.Content.ReadAsStreamAsync().ConfigureAwait(false);
            using var reader = new StreamReader(stream, Encoding.UTF8);

            while (!reader.EndOfStream)
            {
                string? line = await reader.ReadLineAsync().ConfigureAwait(false);
                if (string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }

                PullChunk? chunk;
                try
                {
                    chunk = JsonSerializer.Deserialize<PullChunk>(line);
                }
                catch (JsonException)
                {
                    continue;
                }

                if (chunk is null)
                {
                    continue;
                }

                double? pct = null;
                string detail = string.Empty;
                if (chunk is { Total: > 0, Completed: not null })
                {
                    pct = (double)chunk.Completed.Value / chunk.Total.Value * 100.0;
                    detail = $"{FormatBytes(chunk.Completed.Value)} / {FormatBytes(chunk.Total.Value)}";
                }

                Report(chunk.Status ?? "Downloading...", pct, detail);

                if (string.Equals(chunk.Status, "success", StringComparison.OrdinalIgnoreCase))
                {
                    break;
                }
            }

            Report("Model ready.", 100, string.Empty);
            await Task.Delay(700).ConfigureAwait(false);
        }
        finally
        {
            if (dispatcher is not null && window is not null)
            {
                await dispatcher.InvokeAsync(() => window.Close());
            }
        }
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = { "B", "KB", "MB", "GB" };
        double value = bytes;
        int unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }
        return $"{value:0.0} {units[unit]}";
    }

    private static void ShowMessage(string message, string title)
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null)
        {
            return;
        }
        dispatcher.InvokeAsync(() =>
            MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Information));
    }

    private sealed class PullRequest
    {
        [JsonPropertyName("name")] public string Name { get; set; } = string.Empty;
        [JsonPropertyName("stream")] public bool Stream { get; set; }
    }

    private sealed class PullChunk
    {
        [JsonPropertyName("status")] public string? Status { get; set; }
        [JsonPropertyName("total")] public long? Total { get; set; }
        [JsonPropertyName("completed")] public long? Completed { get; set; }
    }
}
