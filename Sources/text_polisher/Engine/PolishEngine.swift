import Foundation

enum EngineError: LocalizedError {
    case unavailable(String)
    case http(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .http(let code): return "The local model request failed (HTTP \(code))."
        case .empty: return "The model returned no text."
        }
    }
}

/// A text-polishing backend. Implementations stream the cumulative polished
/// text so the UI can update progressively.
protocol PolishEngine: Sendable {
    var displayName: String { get }
    func isAvailable() async -> Bool
    func stream(text: String, tone: Tone) -> AsyncThrowingStream<String, Error>
}
