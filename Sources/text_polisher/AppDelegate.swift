import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PolishCoordinator()
    private let servicesProvider = ServicesProvider()
    private var menuBar: MenuBarController?
    private var hotKey: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFocusTracker.shared.start()
        servicesProvider.coordinator = coordinator
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()

        menuBar = MenuBarController(coordinator: coordinator)

        hotKey = HotKeyManager()
        reloadHotKeys()
        NotificationCenter.default.addObserver(
            self, selector: #selector(shortcutsChanged), name: Settings.shortcutsChanged, object: nil)

        Permissions.ensureAccessibility()
    }

    @objc private func shortcutsChanged() {
        reloadHotKeys()
    }

    /// Re-registers both global shortcuts from the current user preferences.
    private func reloadHotKeys() {
        guard let hotKey else { return }
        hotKey.unregisterAll()
        let settings = Settings.shared
        hotKey.register(settings.polishSelectionShortcut) {
            Task { @MainActor in
                self.coordinator.polishFromHotKey()
            }
        }
        hotKey.register(settings.polishInstantShortcut) {
            Task { @MainActor in
                self.coordinator.polishInstant()
            }
        }
    }
}
