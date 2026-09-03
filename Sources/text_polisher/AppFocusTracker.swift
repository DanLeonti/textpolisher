import AppKit

/// Tracks the most recently active application that isn't us. When polishing is
/// triggered from the Services menu, macOS activates this app first, so reading
/// `frontmostApplication` at that point returns us, not the app the user was
/// actually typing in. Observing activations keeps a reliable reference to the
/// real target app to return focus to.
@MainActor
final class AppFocusTracker {
    static let shared = AppFocusTracker()

    private(set) var lastApp: NSRunningApplication?

    func start() {
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            lastApp = front
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func didActivate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if !isSelf(app) {
            lastApp = app
        }
    }

    private func isSelf(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == NSRunningApplication.current.processIdentifier
            || app.bundleIdentifier == Bundle.main.bundleIdentifier
    }
}
