import Foundation

/// Local polishing via an Ollama server (default http://127.0.0.1:11434).
/// Used as a fallback when Apple's on-device model is unavailable, or when the
/// user prefers a larger/custom local model.
final class OllamaEngine: PolishEngine {
    let displayName = "Ollama (local)"
    private let baseURL: String
    private let model: String

    init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let system: String
        let stream: Bool
    }

    private struct GenerateChunk: Decodable {
        let response: String?
        let done: Bool?
    }

    func stream(text: String, tone: Tone) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "\(baseURL)/api/generate") else {
                        throw EngineError.unavailable("Invalid Ollama URL.")
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let payload = GenerateRequest(
                        model: model,
                        prompt: PromptBuilder.userPrompt(for: text),
                        system: PromptBuilder.instructions(for: tone),
                        stream: true
                    )
                    request.httpBody = try JSONEncoder().encode(payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw EngineError.unavailable("No response from Ollama. Is it running?")
                    }
                    guard http.statusCode == 200 else { throw EngineError.http(http.statusCode) }

                    var accumulated = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(GenerateChunk.self, from: data)
                        else { continue }
                        if let piece = chunk.response, !piece.isEmpty {
                            accumulated += piece
                            continuation.yield(accumulated.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        if chunk.done == true { break }
                    }

                    guard !accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw EngineError.empty
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
