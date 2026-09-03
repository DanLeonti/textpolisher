import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let coordinator: PolishCoordinator
    private let settings = Settings.shared

    private let idleImage = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "TextPolisher")
    private let busyImage = NSImage(systemSymbolName: "wand.and.rays", accessibilityDescription: "TextPolisher (working)")

    init(coordinator: PolishCoordinator) {
        self.coordinator = coordinator
        super.init()

        statusItem.button?.image = idleImage

        let menu = NSMenu()
        menu.delegate = self
        // Background (LSUIElement) apps have no key window or first responder,
        // so AppKit's automatic menu validation disables any item whose target
        // isn't reachable via the responder chain. Disable auto-validation and
        // manage enabled state ourselves.
        menu.autoenablesItems = false
        statusItem.menu = menu

        coordinator.onBusyChanged = { [weak self] busy in
            guard let self else { return }
            self.statusItem.button?.image = busy ? self.busyImage : self.idleImage
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        addItem(to: menu, title: "Polish Clipboard Text", action: #selector(polishClipboard))
        addItem(to: menu, title: "Polish Selected Text (\(settings.polishSelectionShortcut.displayString))",
                action: #selector(polishSelection))
        addItem(to: menu, title: "Polish & Replace Now (\(settings.polishInstantShortcut.displayString))",
                action: #selector(polishInstant))

        menu.addItem(.separator())
        menu.addItem(engineMenuItem())
        menu.addItem(toneMenuItem())
        addItem(to: menu, title: "Shortcuts\u{2026}", action: #selector(openShortcuts))

        menu.addItem(.separator())
        addItem(to: menu, title: "On-Device Model Status\u{2026}", action: #selector(showModelStatus))
        addItem(to: menu, title: "Accessibility Settings\u{2026}", action: #selector(openAccessibility))
        addItem(to: menu, title: "Check for Updates\u{2026}", action: #selector(checkForUpdates))

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit TextPolisher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
        return item
    }

    private func engineMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Engine", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for choice in Settings.EngineChoice.allCases {
            let item = NSMenuItem(title: choice.title, action: #selector(selectEngine(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = (choice == settings.engineChoice) ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func toneMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Default Tone", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for tone in Tone.allCases {
            let item = NSMenuItem(title: tone.title, action: #selector(selectTone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tone.rawValue
            item.state = (tone == settings.defaultTone) ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    @objc private func polishClipboard() {
        guard let text = PasteboardHelper.string(), !text.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Clipboard is empty"
            alert.informativeText = "Copy some text first, then choose Polish Clipboard Text."
            alert.runModal()
            return
        }
        coordinator.polish(text: text)
    }

    @objc private func polishSelection() {
        coordinator.polishFromHotKey()
    }

    @objc private func polishInstant() {
        coordinator.polishInstant()
    }

    @objc private func selectEngine(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let choice = Settings.EngineChoice(rawValue: raw) else { return }
        settings.engineChoice = choice
    }

    @objc private func selectTone(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let tone = Tone(rawValue: raw) else { return }
        settings.defaultTone = tone
    }

    @objc private func showModelStatus() {
        let status = FoundationModelsEngine.status()
        let alert = NSAlert()
        if status.isAvailable {
            alert.messageText = "Apple On-Device Model"
            alert.informativeText = status.shortDescription
            alert.runModal()
            return
        }
        let guidance = FoundationModelsEngine.guidance(for: status)
        alert.messageText = guidance.title
        alert.informativeText = guidance.message
        alert.alertStyle = .informational
        if guidance.canOpenAppleIntelligence {
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Close")
            if alert.runModal() == .alertFirstButtonReturn {
                Permissions.openAppleIntelligenceSettings()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func openAccessibility() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func checkForUpdates() {
        let progress = NSAlert()
        progress.messageText = "Checking for updates\u{2026}"
        progress.informativeText = "Contacting textpolisher.app."
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        spinner.startAnimation(nil)
        progress.accessoryView = spinner
        progress.addButton(withTitle: "Cancel")

        Task {
            let result = await UpdateChecker.check()
            progress.window.close()
            presentUpdateResult(result)
        }
        progress.runModal()
    }

    private func presentUpdateResult(_ result: UpdateChecker.Result) {
        let alert = NSAlert()
        switch result {
        case .upToDate(let current):
            alert.messageText = "You\u{2019}re up to date"
            alert.informativeText = "TextPolisher \(current) is the latest version."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()

        case .updateAvailable(let latest, let current, let downloadURL, let notes):
            alert.messageText = "A new version is available"
            var body = "You have version \(current). Version \(latest) is available."
            if let notes, !notes.isEmpty { body += "\n\n\(notes)" }
            body += "\n\nDownload it now?"
            alert.informativeText = body
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(downloadURL)
            }

        case .failed(let message):
            alert.messageText = "Couldn\u{2019}t check for updates"
            alert.informativeText = "\(message)\n\nYou can always download the latest version from textpolisher.app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Website")
            alert.addButton(withTitle: "Close")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(UpdateChecker.websiteURL)
            }
        }
    }

    @objc private func openShortcuts() {
        PreferencesWindowController.shared.show()
    }
}
