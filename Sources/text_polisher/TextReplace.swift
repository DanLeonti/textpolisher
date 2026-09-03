import AppKit
import ApplicationServices

/// Replaces the current selection in the frontmost app with polished text, in
/// order of preference:
///   1. Accessibility set value on the focused field (clean, no clipboard use).
///   2. Accessibility "Edit ▸ Paste" menu action. Not a synthesized keystroke,
///      so it is NOT blocked by macOS Secure Input (which Chromium/Electron apps
///      like Slack and browsers frequently leave stuck on).
///   3. Synthesized Cmd+V (universal, but blocked while Secure Input is active).
@MainActor
final class TextReplace {
    /// Called when no replace path could run because macOS Secure Input is
    /// active. The polished text is left on the clipboard for a manual paste.
    var onSecureInputBlocked: (() -> Void)?

    func replace(with text: String) {
        if accessibilityReplace(text) {
            Log.replace.info("Replaced via Accessibility set-value (\(text.count, privacy: .public) chars)")
            return
        }
        Log.replace.info("AX set-value unavailable on focused field; using paste fallback")
        pasteReplace(text)
    }

    private func accessibilityReplace(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focusedElement = focused else { return false }
        let element = focusedElement as! AXUIElement

        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue else { return false }

        // Snapshot the field before writing so we can confirm the write landed.
        // Chromium/Electron apps (Slack, browsers) advertise AXSelectedText as
        // settable and return .success on the write, but never apply it to their
        // web editor — a silent no-op. Trusting that would leave the user with
        // unchanged text and we'd never try the paste fallback. Reading the value
        // back and requiring it to actually change defeats that false success.
        let before = fieldValue(of: element)
        let beforeSelection = selectedText(of: element)

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        guard result == .success else { return false }

        // If the polished text equals what was already selected, there is nothing
        // to change — treat the write as effective so we don't paste needlessly.
        if let beforeSelection, beforeSelection == text { return true }

        // If we can read the field value and it didn't change at all, the write
        // was a no-op (the Slack/Electron case). Report failure so the caller
        // falls through to the paste path.
        if let before, let after = fieldValue(of: element), before == after {
            Log.replace.info("AX set-value returned success but field is unchanged; falling back to paste")
            return false
        }
        return true
    }

    private func fieldValue(of element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success else { return nil }
        return valueRef as? String
    }

    private func selectedText(of element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &valueRef) == .success else { return nil }
        return valueRef as? String
    }

    private func pasteReplace(_ text: String) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let secureInput = KeyboardSimulator.isSecureInputEnabled
        Log.replace.info("Paste fallback. frontmost=\(frontmost, privacy: .public) secureInput=\(secureInput, privacy: .public)")

        let backup = PasteboardHelper.snapshot()
        PasteboardHelper.setString(text)

        // Preferred fallback: trigger the app's Edit ▸ Paste menu item via the
        // Accessibility API. An AX menu action is not a synthesized keystroke, so
        // it works even when Secure Input is stuck on (the common Slack/browser
        // failure). This is why we try it before a synthesized Cmd+V.
        if performMenuPaste() {
            Log.replace.info("Pasted via Edit>Paste menu action (AX)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                PasteboardHelper.restore(backup)
            }
            return
        }
        Log.replace.info("Menu paste unavailable; trying synthesized Cmd+V")

        // Last resort: synthesized Cmd+V, which Secure Input silently drops. If
        // it's active, tell the user instead of failing quietly and leave the
        // text on the clipboard (don't restore the backup) so a manual Cmd+V or
        // app restart still gets them their polished text.
        if secureInput {
            Log.replace.error("Secure Input active: synthesized Cmd+V is blocked. Left text on clipboard.")
            onSecureInputBlocked?()
            return
        }

        Log.replace.info("Pasting via synthesized Cmd+V")
        KeyboardSimulator.waitForModifiersReleased()
        KeyboardSimulator.paste()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            PasteboardHelper.restore(backup)
        }
    }

    /// Invokes the frontmost app's Paste command through its menu bar using the
    /// Accessibility API. Returns true if the Paste item was found and pressed.
    private func performMenuPaste() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            Log.replace.info("Menu paste: no eligible frontmost app")
            return false
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBarValue = menuBarRef else {
            Log.replace.info("Menu paste: no AX menu bar")
            return false
        }
        let menuBar = menuBarValue as! AXUIElement
        guard let pasteItem = findPasteItem(in: menuBar, depth: 0) else {
            Log.replace.info("Menu paste: Cmd+V Paste item not found in menu")
            return false
        }
        let result = AXUIElementPerformAction(pasteItem, kAXPressAction as CFString)
        if result != .success {
            Log.replace.error("Menu paste: AXPress failed (code \(result.rawValue, privacy: .public))")
        }
        return result == .success
    }

    /// Depth-first search for the menu item bound to Cmd+V (Paste), matched by
    /// keyboard shortcut rather than localized title so it works in any language
    /// and won't match "Paste and Match Style" (Cmd+Shift+V).
    private func findPasteItem(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth <= 4 else { return nil }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children {
            if isPasteItem(child) { return child }
            if let found = findPasteItem(in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    private func isPasteItem(_ element: AXUIElement) -> Bool {
        var charRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &charRef) == .success,
              let cmdChar = charRef as? String, cmdChar.lowercased() == "v" else { return false }

        // kAXMenuItemCmdModifiers: 0 == Command only. A non-zero value means an
        // extra modifier (e.g. Shift for "Paste and Match Style"), which we skip.
        var modifiersRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersRef) == .success,
           let modifiers = modifiersRef as? Int, modifiers != 0 {
            return false
        }

        var enabledRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledRef) == .success,
           let enabled = enabledRef as? Bool, enabled == false {
            return false
        }
        return true
    }
}
