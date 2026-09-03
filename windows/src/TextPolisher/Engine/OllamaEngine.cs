using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace TextPolisher.Engine;

/// <summary>
/// Local text polishing via an Ollama HTTP server. Mirrors the macOS OllamaEngine:
/// POST /api/generate with a system+prompt payload and stream: true (NDJSON).
/// </summary>
public sealed class OllamaEngine : IPolishEngine
{
    private static readonly HttpClient StreamClient = new()
    {
        // No overall timeout: streaming responses stay open for the duration of
        // generation. Cancellation is driven by the CancellationToken instead.
        Timeout = Timeout.InfiniteTimeSpan,
    };

    private readonly string _baseUrl;
    private readonly string _model;

    public OllamaEngine(string baseUrl, string model)
    {
        _baseUrl = baseUrl.TrimEnd('/');
        _model = model;
    }

    public string DisplayName => "Ollama (local)";

    public async Task<bool> IsAvailableAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromSeconds(2));
            using var request = new HttpRequestMessage(HttpMethod.Get, $"{_baseUrl}/api/tags");
            using var response = await StreamClient.SendAsync(request, cts.Token).ConfigureAwait(false);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<IReadOnlyList<string>> ListModelsAsync(CancellationToken cancellationToken = default)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(TimeSpan.FromSeconds(5));
        try
        {
            var tags = await StreamClient.GetFromJsonAsync<TagsResponse>(
                $"{_baseUrl}/api/tags", cts.Token).ConfigureAwait(false);
            return tags?.Models?.Select(m => m.Name ?? string.Empty)
                       .Where(n => n.Length > 0).ToList() ?? new List<string>();
        }
        catch
        {
            return new List<string>();
        }
    }

    public async IAsyncEnumerable<string> StreamAsync(
        string text, Tone tone, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var payload = new GenerateRequest
        {
            Model = _model,
            Prompt = PromptBuilder.UserPrompt(text),
            System = PromptBuilder.Instructions(tone),
            Stream = true,
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, $"{_baseUrl}/api/generate")
        {
            Content = new StringContent(
                JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"),
        };

        HttpResponseMessage response;
        try
        {
            response = await StreamClient.SendAsync(
                request, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw EngineException.Unavailable(
                $"Could not reach the local model server at {_baseUrl}. Is Ollama running? ({ex.Message})");
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                throw EngineException.Http((int)response.StatusCode);
            }

            var accumulated = new StringBuilder();
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            using var reader = new StreamReader(stream, Encoding.UTF8);

            while (!reader.EndOfStream)
            {
                if (cancellationToken.IsCancellationRequested)
                {
                    yield break;
                }

                string? line = await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false);
                if (string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }

                GenerateChunk? chunk;
                try
                {
                    chunk = JsonSerializer.Deserialize<GenerateChunk>(line);
                }
                catch (JsonException)
                {
                    continue;
                }

                if (chunk is null)
                {
                    continue;
                }

                if (!string.IsNullOrEmpty(chunk.Response))
                {
                    accumulated.Append(chunk.Response);
                    yield return accumulated.ToString().Trim();
                }

                if (chunk.Done == true)
                {
                    break;
                }
            }

            if (accumulated.ToString().Trim().Length == 0)
            {
                throw EngineException.Empty();
            }
        }
    }

    private sealed class GenerateRequest
    {
        [JsonPropertyName("model")] public string Model { get; set; } = string.Empty;
        [JsonPropertyName("prompt")] public string Prompt { get; set; } = string.Empty;
        [JsonPropertyName("system")] public string System { get; set; } = string.Empty;
        [JsonPropertyName("stream")] public bool Stream { get; set; }
    }

    private sealed class GenerateChunk
    {
        [JsonPropertyName("response")] public string? Response { get; set; }
        [JsonPropertyName("done")] public bool? Done { get; set; }
    }

    private sealed class TagsResponse
    {
        [JsonPropertyName("models")] public List<TagModel>? Models { get; set; }
    }

    private sealed class TagModel
    {
        [JsonPropertyName("name")] public string? Name { get; set; }
    }
}
