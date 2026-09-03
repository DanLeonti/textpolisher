import AppKit
import ApplicationServices

/// Reads the user's currently selected text from whatever app is frontmost,
/// using a layered fallback strategy:
///   1. Accessibility API (fast, no clipboard side effects)
///   2. AppleScript for known browsers (best effort)
///   3. Synthesized Cmd+C with pasteboard backup/restore (universal)
@MainActor
final class TextCapture {
    func currentSelection() -> String? {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let secureInput = KeyboardSimulator.isSecureInputEnabled
        Log.capture.info("Capture start. frontmost=\(frontmost, privacy: .public) secureInput=\(secureInput, privacy: .public)")

        // Chromium browsers, and Electron apps built on Chromium (Slack,
        // WhatsApp, Discord, Teams), only expose their web content to the
        // Accessibility API once accessibility is switched on. Nudge it on so
        // the clean AX path (below) can read the selection directly, instead
        // of always falling back to a synthesized Cmd+C.
        enableWebAccessibilityIfChromiumBased()

        if let viaAX = accessibilitySelection(), !viaAX.isEmpty {
            Log.capture.info("Captured via Accessibility (\(viaAX.count, privacy: .public) chars)")
            return viaAX
        }
        Log.capture.info("AX selection empty/unavailable; trying browser AppleScript")

        if let viaBrowser = browserSelection(), !viaBrowser.isEmpty {
            Log.capture.info("Captured via browser AppleScript (\(viaBrowser.count, privacy: .public) chars)")
            return viaBrowser
        }
        Log.capture.info("Browser AppleScript empty/unavailable; trying synthesized Cmd+C")

        let copied = copySelection()
        if let copied, !copied.isEmpty {
            Log.capture.info("Captured via synthesized Cmd+C (\(copied.count, privacy: .public) chars)")
            return copied
        }
        if secureInput {
            Log.capture.error("Capture failed: Cmd+C produced nothing and Secure Input is active (likely blocking the copy)")
        } else {
            Log.capture.error("Capture failed: no selection from AX, browser, or Cmd+C (nothing selected, or app exposes no selection)")
        }
        return copied
    }

    private func accessibilitySelection() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focusedElement = focused else { return nil }
        let element = focusedElement as! AXUIElement

        var selRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selRef) == .success,
              let text = selRef as? String, !text.isEmpty else { return nil }

        // Electron/web editors (Slack, browsers) strip newlines from
        // kAXSelectedTextAttribute. Cross-check using kAXSelectedTextRange +
        // kAXValue: the full field value preserves newlines, so extracting the
        // selected range from it gives us the text as the user actually typed it.
        // Only trust that extraction if it agrees with the direct attribute
        // once whitespace/newlines are ignored — some apps (e.g. Jira's
        // rich-text editor) report a kAXValue that doesn't correspond 1:1 with
        // the kAXSelectedTextRange coordinates, which silently corrupts the
        // extracted substring even when the offset math itself is correct.
        if let extracted = rangeExtractedSelection(element: element), textsAgreeIgnoringWhitespace(extracted, text) {
            Log.capture.info("AX range-extract gave \(extracted.count, privacy: .public) chars (direct attr gave \(text.count, privacy: .public))")
            return extracted
        }
        return text
    }

    private func rangeExtractedSelection(element: AXUIElement) -> String? {
        var rangeRef: CFTypeRef?
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef,
              AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String else { return nil }

        var cfRange = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange), cfRange.length > 0 else { return nil }

        // cfRange.location/.length are UTF-16 code-unit offsets (the AX API is
        // NSString-based), NOT Swift grapheme-cluster offsets. Indexing
        // fullText directly with offsetBy: silently drifts whenever any
        // earlier character composes differently between the two counting
        // schemes, and that drift compounds with distance into the document.
        // Indexing via the utf16 view matches AX's convention exactly.
        let utf16 = fullText.utf16
        guard let start16 = utf16.index(utf16.startIndex, offsetBy: cfRange.location, limitedBy: utf16.endIndex),
              let end16 = utf16.index(start16, offsetBy: cfRange.length, limitedBy: utf16.endIndex),
              let start = String.Index(start16, within: fullText),
              let end = String.Index(end16, within: fullText)
        else {
            Log.capture.error("AX range-extract: offsets out of bounds against kAXValue")
            return nil
        }
        let extracted = String(fullText[start..<end])
        return extracted.isEmpty ? nil : extracted
    }

    /// The range-extracted text should carry the exact same non-whitespace
    /// content as the direct attribute — it only ever adds back newlines that
    /// some apps strip. If they disagree beyond whitespace, kAXValue and
    /// kAXSelectedTextRange don't describe the same text for this element, so
    /// trusting the extraction would silently corrupt the capture.
    private func textsAgreeIgnoringWhitespace(_ a: String, _ b: String) -> Bool {
        func collapsed(_ s: String) -> String {
            String(String.UnicodeScalarView(s.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }))
        }
        return collapsed(a) == collapsed(b)
    }

    private static let chromiumBasedBundleIDs: Set<String> = [
        // Standalone browsers
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.brave.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera", "company.thebrowser.Browser", "com.google.Chrome.dev",
        // Electron apps embedding Chromium — same web-content AX gap as browsers
        "com.tinyspeck.slackmacgap", "net.whatsapp.WhatsApp", "com.hnc.Discord",
        "com.microsoft.teams", "com.microsoft.teams2"
    ]

    /// Chromium (standalone or embedded in an Electron app) exposes its web
    /// content to the Accessibility API only after accessibility is enabled
    /// (normally it waits to detect a screen reader). Setting the private
    /// "AXManualAccessibility" attribute on the app element turns the a11y
    /// tree on, which lets `accessibilitySelection()` read a selection inside
    /// pages like Jira, or composer boxes like Slack's, without touching the
    /// clipboard.
    private func enableWebAccessibilityIfChromiumBased() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              Self.chromiumBasedBundleIDs.contains(bundleID) else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    private func browserSelection() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return nil }

        let source: String
        switch bundleID {
        case "com.apple.Safari":
            source = "tell application \"Safari\" to do JavaScript \"window.getSelection().toString()\" in front document"
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac",
             "com.vivaldi.Vivaldi", "company.thebrowser.Browser":
            let name = app.localizedName ?? "Google Chrome"
            source = "tell application \"\(name)\" to execute front window's active tab javascript \"window.getSelection().toString()\""
        default:
            return nil
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }

    private func copySelection() -> String? {
        // The hotkey chord (e.g. Cmd+Opt+P) is usually still held here; if we
        // synthesize Cmd+C now, the held Opt merges in and it becomes Cmd+Opt+C,
        // which copies nothing. Wait for the user to let go first.
        KeyboardSimulator.waitForModifiersReleased()

        let backup = PasteboardHelper.snapshot()
        NSPasteboard.general.clearContents()
        let baseline = PasteboardHelper.changeCount

        KeyboardSimulator.copy()

        var captured: String?
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            if PasteboardHelper.changeCount != baseline {
                captured = PasteboardHelper.string()
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        PasteboardHelper.restore(backup)
        return captured
    }
}
