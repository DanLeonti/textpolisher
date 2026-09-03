import AppKit

/// Exposes the "Polish Text" item in the system Services menu (right-click ->
/// Services) for any selected text. Declared in Info.plist under NSServices with
/// NSMessage = polishText.
@MainActor
final class ServicesProvider: NSObject {
    var coordinator: PolishCoordinator?

    @objc func polishText(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error?.pointee = "No text was selected." as NSString
            return
        }
        coordinator?.polish(text: text)
    }
}
