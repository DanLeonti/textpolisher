import AppIntents

/// Polishes a piece of text on-device and returns the result. Clipboard access
/// is intentionally handled by the Shortcut (Get Clipboard -> Polish -> Copy to
/// Clipboard), because a background App Intent cannot read `UIPasteboard.general`.
///
/// Returns only a value (no dialog/snippet) so the system shows its own brief,
/// self-dismissing run indicator instead of a card with a "Done" button. For the
/// Share Sheet (selected text) flow, see `PolishSelectionIntent`.
struct PolishIntent: AppIntent {
    static let title: LocalizedStringResource = "Polish Text"
    static let description = IntentDescription(
        "Rewrites the provided text on-device using your default tone and returns the polished version."
    )

    /// Runs silently in the background instead of launching the app.
    static let openAppWhenRun = false

    @Parameter(title: "Text", description: "The text to polish (usually the clipboard).")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Polish \(\.$text)")
    }

    func perform() async throws -> some ReturnsValue<String> {
        let cleaned = try await PolishRunner.polish(text)
        return .result(value: cleaned)
    }
}
