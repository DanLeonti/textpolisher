import Foundation

/// Shared polishing pipeline used by every entry point (the silent clipboard
/// App Intent, the Share Sheet intent, and the Action Extension). Keeping it in
/// one place means the prompt, tone handling, and output cleanup behave
/// identically no matter how the user triggers a polish.
enum PolishRunner {
    enum Failure: Error, LocalizedError, CustomLocalizedStringResourceConvertible {
        case message(String)

        var errorDescription: String? {
            switch self {
            case .message(let text): return text
            }
        }

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .message(let text): return LocalizedStringResource(stringLiteral: text)
            }
        }
    }

    static func polish(_ raw: String, tone: Tone = ToneStore.defaultTone) async throws -> String {
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else {
            throw Failure.message("Nothing to polish - select some text first.")
        }

        let engine = FoundationModelsEngine()
        guard await engine.isAvailable() else {
            throw Failure.message("Apple Intelligence is unavailable. Enable it in Settings.")
        }

        var polished = ""
        for try await chunk in engine.stream(text: original, tone: tone) {
            polished = chunk
        }

        let cleaned = OutputCleaner.clean(polished)
        guard !cleaned.isEmpty else {
            throw Failure.message("The model returned no text. Try again.")
        }
        return cleaned
    }
}
