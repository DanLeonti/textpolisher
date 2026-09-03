import Foundation

enum Tone: String, CaseIterable, Identifiable, Sendable {
    case fixGrammar
    case professional
    case friendly
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixGrammar: return "Fix Grammar"
        case .professional: return "Professional"
        case .friendly: return "Friendly"
        case .concise: return "Concise"
        }
    }

    var systemImage: String {
        switch self {
        case .fixGrammar: return "checkmark.seal"
        case .professional: return "briefcase"
        case .friendly: return "face.smiling"
        case .concise: return "scissors"
        }
    }

    var guidance: String {
        switch self {
        case .fixGrammar:
            return "Fix spelling, grammar, and punctuation only. Preserve the original meaning, tone, and wording as closely as possible and avoid rephrasing that is not required for correctness. If the text is already correct, return it unchanged."
        case .professional:
            return "Rewrite the text so it reads clearly and professionally, suitable for a workplace chat message. Keep it natural and human, not stiff or formal to the point of sounding robotic. Always produce a polished rewrite in this style, even when the original is already grammatically correct — for example, turn a terse fragment like \"need help with cursor limit increase\" into a complete, professional sentence."
        case .friendly:
            return "Rewrite the text so it sounds warm, friendly, and approachable while staying clear and to the point. Always produce a rewrite in this style, even when the original is already grammatically correct."
        case .concise:
            return "Rewrite the text to be as clear and concise as possible, removing filler while keeping every important detail. Always produce a tightened rewrite in this style, even when the original is already grammatically correct."
        }
    }
}
