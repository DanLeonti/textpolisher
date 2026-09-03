import Foundation
import Carbon.HIToolbox

final class Settings: @unchecked Sendable {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// Posted whenever a global shortcut changes so the hotkeys can re-register.
    static let shortcutsChanged = Notification.Name("TextPolisherShortcutsChanged")

    static let defaultPolishSelection = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(cmdKey | optionKey))
    static let defaultPolishInstant = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(cmdKey | optionKey | shiftKey))

    enum EngineChoice: String, CaseIterable {
        case auto
        case appleOnDevice
        case ollama

        var title: String {
            switch self {
            case .auto: return "Automatic"
            case .appleOnDevice: return "Apple On-Device"
            case .ollama: return "Ollama (local)"
            }
        }
    }

    private enum Keys {
        static let engine = "engineChoice"
        static let tone = "defaultTone"
        static let ollamaModel = "ollamaModel"
        static let ollamaBaseURL = "ollamaBaseURL"
        static let selectionKeyCode = "polishSelectionKeyCode"
        static let selectionModifiers = "polishSelectionModifiers"
        static let instantKeyCode = "polishInstantKeyCode"
        static let instantModifiers = "polishInstantModifiers"
    }

    var engineChoice: EngineChoice {
        get { EngineChoice(rawValue: defaults.string(forKey: Keys.engine) ?? "") ?? .auto }
        set { defaults.set(newValue.rawValue, forKey: Keys.engine) }
    }

    var defaultTone: Tone {
        get { Tone(rawValue: defaults.string(forKey: Keys.tone) ?? "") ?? .fixGrammar }
        set { defaults.set(newValue.rawValue, forKey: Keys.tone) }
    }

    var ollamaBaseURL: String {
        get { defaults.string(forKey: Keys.ollamaBaseURL) ?? "http://127.0.0.1:11434" }
        set { defaults.set(newValue, forKey: Keys.ollamaBaseURL) }
    }

    var ollamaModel: String {
        get { defaults.string(forKey: Keys.ollamaModel) ?? "llama3.2" }
        set { defaults.set(newValue, forKey: Keys.ollamaModel) }
    }

    var polishSelectionShortcut: KeyboardShortcut {
        get { shortcut(keyKey: Keys.selectionKeyCode, modKey: Keys.selectionModifiers,
                       default: Settings.defaultPolishSelection) }
        set { setShortcut(newValue, keyKey: Keys.selectionKeyCode, modKey: Keys.selectionModifiers) }
    }

    var polishInstantShortcut: KeyboardShortcut {
        get { shortcut(keyKey: Keys.instantKeyCode, modKey: Keys.instantModifiers,
                       default: Settings.defaultPolishInstant) }
        set { setShortcut(newValue, keyKey: Keys.instantKeyCode, modKey: Keys.instantModifiers) }
    }

    private func shortcut(keyKey: String, modKey: String, default fallback: KeyboardShortcut) -> KeyboardShortcut {
        guard defaults.object(forKey: keyKey) != nil else { return fallback }
        return KeyboardShortcut(
            keyCode: UInt32(defaults.integer(forKey: keyKey)),
            carbonModifiers: UInt32(defaults.integer(forKey: modKey)))
    }

    private func setShortcut(_ shortcut: KeyboardShortcut, keyKey: String, modKey: String) {
        defaults.set(Int(shortcut.keyCode), forKey: keyKey)
        defaults.set(Int(shortcut.carbonModifiers), forKey: modKey)
        NotificationCenter.default.post(name: Settings.shortcutsChanged, object: nil)
    }
}

@MainActor
final class EngineProvider {
    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    func currentEngine() async -> any PolishEngine {
        switch settings.engineChoice {
        case .appleOnDevice:
            return FoundationModelsEngine()
        case .ollama:
            return OllamaEngine(baseURL: settings.ollamaBaseURL, model: settings.ollamaModel)
        case .auto:
            let apple = FoundationModelsEngine()
            if await apple.isAvailable() { return apple }
            return OllamaEngine(baseURL: settings.ollamaBaseURL, model: settings.ollamaModel)
        }
    }
}
