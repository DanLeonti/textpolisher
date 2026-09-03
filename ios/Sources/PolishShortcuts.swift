import AppIntents

/// Surfaces the polish intents as App Shortcuts. `PolishIntent` powers the
/// Action Button / Back Tap / Siri (clipboard) flow; `PolishSelectionIntent`
/// makes "Polish Selected Text" appear in the Share Sheet for highlighted text,
/// since an App Shortcut whose intent takes a `String` parameter is offered
/// automatically when the user shares text.
struct PolishShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PolishIntent(),
            phrases: [
                "Polish my text with \(.applicationName)",
                "Polish my clipboard with \(.applicationName)",
                "\(.applicationName) polish my text"
            ],
            shortTitle: "Polish Text",
            systemImageName: "wand.and.stars"
        )
        AppShortcut(
            intent: PolishSelectionIntent(),
            phrases: [
                "Polish the selected text with \(.applicationName)",
                "\(.applicationName) polish this"
            ],
            shortTitle: "Polish Selection",
            systemImageName: "text.cursor"
        )
    }
}
