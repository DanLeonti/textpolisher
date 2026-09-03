import Foundation
import FoundationModels

/// On-device polishing using Apple's Foundation Models framework. Fully local,
/// private, offline-capable, and free (no API key).
final class FoundationModelsEngine: PolishEngine {
    let displayName = "Apple On-Device"

    func isAvailable() async -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        return false
    }

    /// Why Apple's on-device model can or can't be used right now. Lets us show
    /// users a specific, actionable message instead of a raw framework error.
    enum AppleIntelligenceStatus: Sendable, Equatable {
        case available
        case notEnabled          // Apple Intelligence toggle is off.
        case notReady            // Enabled, but the model is still downloading/preparing.
        case deviceNotEligible   // Hardware, region, or language not supported.
        case unsupportedOS       // Older than macOS 26.

        var isAvailable: Bool { self == .available }

        /// One-line summary for the menu-bar status item and engine errors.
        var shortDescription: String {
            switch self {
            case .available:
                return "Available — ready to polish on-device."
            case .notEnabled:
                return "Apple Intelligence is turned off. Turn it on in System Settings \u{203A} Apple Intelligence & Siri."
            case .notReady:
                return "Apple Intelligence is still preparing its on-device model. Try again in a few minutes."
            case .deviceNotEligible:
                return "Apple Intelligence isn't supported on this Mac. Switch the engine to Ollama from the menu-bar wand icon."
            case .unsupportedOS:
                return "Apple Intelligence requires macOS 26 (Tahoe) or later."
            }
        }
    }

    /// A user-facing prompt (title + body) for an unavailable state, plus whether
    /// offering an "Open Settings" button to Apple Intelligence makes sense.
    struct Guidance: Sendable {
        let title: String
        let message: String
        let canOpenAppleIntelligence: Bool
    }

    static func status() -> AppleIntelligenceStatus {
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                return .notEnabled
            case .unavailable(.modelNotReady):
                return .notReady
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable:
                return .deviceNotEligible
            @unknown default:
                return .deviceNotEligible
            }
        }
        return .unsupportedOS
    }

    static func guidance(for status: AppleIntelligenceStatus) -> Guidance {
        switch status {
        case .available:
            return Guidance(title: "Apple Intelligence is ready", message: "", canOpenAppleIntelligence: false)
        case .notEnabled:
            return Guidance(
                title: "Turn on Apple Intelligence",
                message: """
                TextPolisher rewrites your text on-device using Apple Intelligence, but it's currently turned off.

                Open System Settings \u{203A} Apple Intelligence & Siri, turn on Apple Intelligence, then try again.

                Prefer not to use it? You can switch the engine to a local Ollama model from the menu-bar wand icon.
                """,
                canOpenAppleIntelligence: true)
        case .notReady:
            return Guidance(
                title: "Apple Intelligence is getting ready",
                message: """
                Apple Intelligence is on, but it's still downloading or preparing its on-device model. This can take a few minutes after you first enable it or update macOS.

                Wait a little and try again. You can check progress in System Settings \u{203A} Apple Intelligence & Siri.
                """,
                canOpenAppleIntelligence: true)
        case .deviceNotEligible:
            return Guidance(
                title: "Apple Intelligence isn't available on this Mac",
                message: """
                This Mac doesn't support Apple Intelligence (it needs Apple silicon and a supported region and language).

                You can still use TextPolisher with a local model: install Ollama from ollama.com, then set the engine to Ollama from the menu-bar wand icon.
                """,
                canOpenAppleIntelligence: false)
        case .unsupportedOS:
            return Guidance(
                title: "Update macOS to use Apple Intelligence",
                message: """
                Apple Intelligence requires macOS 26 (Tahoe) or later.

                Update macOS, or use a local Ollama model instead (set the engine to Ollama from the menu-bar wand icon).
                """,
                canOpenAppleIntelligence: false)
        }
    }

    static func availabilityDescription() -> String {
        status().shortDescription
    }

    func stream(text: String, tone: Tone) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard #available(iOS 26.0, macOS 26.0, *) else {
                        throw EngineError.unavailable("Foundation Models requires iOS 26 / macOS 26 or later.")
                    }
                    let status = FoundationModelsEngine.status()
                    guard status.isAvailable else {
                        throw EngineError.unavailable(status.shortDescription)
                    }
                    // TextPolisher only ever transforms text a person already wrote —
                    // it never generates novel content — so the permissive guardrail
                    // mode is the appropriate fit. It avoids false-positive
                    // `guardrailViolation` errors on ordinary work text that merely
                    // mentions sensitive-sounding topics (e.g. fraud/security
                    // tickets discussing "scam" detection rules).
                    let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
                    let session = LanguageModelSession(model: model, instructions: PromptBuilder.instructions(for: tone))
                    let response = try await session.respond(to: PromptBuilder.userPrompt(for: text))
                    let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !content.isEmpty else { throw EngineError.empty }
                    continuation.yield(content)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch LanguageModelSession.GenerationError.guardrailViolation {
                    // Even in permissive mode, the model can still refuse truly
                    // sensitive content by generating a refusal string rather than
                    // throwing — this catch only fires for the rarer cases (e.g.
                    // guided generation) that bypass permissive mode entirely.
                    continuation.finish(throwing: EngineError.unavailable(
                        "Apple's on-device safety filter blocked this text. This can happen with wording related to security, fraud, or other sensitive topics — even in legitimate work content. Try rephrasing slightly, or try again."))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
