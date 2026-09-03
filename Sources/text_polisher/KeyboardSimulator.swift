import AppKit
import Carbon.HIToolbox

enum KeyboardSimulator {
    /// macOS "Secure Input" (`EnableSecureEventInput`) blocks synthesized key
    /// events system-wide. It's turned on for password fields, but Chromium /
    /// Electron apps (Slack, etc.) have a long-standing bug where they leave it
    /// enabled after a secure field loses focus, until the app is restarted.
    /// When it's on, a synthesized Cmd+V is silently dropped.
    static var isSecureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }

    static func keyCombo(_ keyCode: CGKeyCode, flags: CGEventFlags = .maskCommand) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Blocks briefly until the user releases keyboard modifier keys.
    ///
    /// Our shortcuts are chords (e.g. Cmd+Opt+P). When the handler fires, those
    /// keys are usually still physically held. A synthesized Cmd+C/Cmd+V posted
    /// at the HID tap gets OR'd with the held hardware modifiers, so Cmd+C turns
    /// into Cmd+Opt+C and does nothing. Waiting for release makes the synthesized
    /// combo land cleanly. Falls through after `timeout` so we never hang.
    @discardableResult
    static func waitForModifiersReleased(timeout: TimeInterval = 0.5) -> Bool {
        let tracked: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let held = CGEventSource.flagsState(.combinedSessionState).intersection(tracked)
            if held.isEmpty { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        return false
    }

    static func copy() {
        keyCombo(CGKeyCode(kVK_ANSI_C))
    }

    static func paste() {
        keyCombo(CGKeyCode(kVK_ANSI_V))
    }
}
