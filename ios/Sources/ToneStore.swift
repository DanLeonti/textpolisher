import Foundation

/// Persists the user's default polishing tone. The app UI writes it and the
/// App Intent reads it, both running in the same process so `UserDefaults`
/// is sufficient (no app group required).
enum ToneStore {
    private static let key = "defaultTone"

    static var defaultTone: Tone {
        get { Tone(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .fixGrammar }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
