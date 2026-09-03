import AppIntents
import UIKit

/// The Share Sheet entry point. Because this intent takes a single `String`
/// parameter and is registered in `PolishShortcuts`, iOS surfaces it in the
/// Share Sheet whenever the user selects text and taps Share - the selection is
/// passed straight into `text`.
///
/// Unlike `PolishIntent`, this one is meant to be *seen*: it copies the polished
/// result to the clipboard (writing the pasteboard from a background intent is
/// allowed - only reading is restricted) and returns a dialog so the result is
/// shown for review before the user pastes it back.
struct PolishSelectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Polish Selected Text"
    static let description = IntentDescription(
        "Polishes selected or shared text on-device, copies the result to the clipboard, and shows it so you can paste it back."
    )

    static let openAppWhenRun = false

    @Parameter(title: "Text", description: "The selected or shared text to polish.")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Polish selected \(\.$text)")
    }

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let cleaned = try await PolishRunner.polish(text)
        UIPasteboard.general.string = cleaned
        return .result(
            value: cleaned,
            dialog: IntentDialog(stringLiteral: cleaned)
        )
    }
}
