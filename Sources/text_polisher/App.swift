import AppKit

@main
@MainActor
struct TextPolisherApp {
    // NSApplication.delegate is weak, so we must hold our own strong reference
    // for the lifetime of the process. Assigned inside main() after NSApplication
    // is ready, then retained here so it is never deallocated.
    nonisolated(unsafe) private static var _delegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        _delegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
