import AppKit

/// A small window letting the user record their own global shortcuts for the
/// preview and instant-polish actions.
@MainActor
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let settings = Settings.shared
    private let selectionRecorder = ShortcutRecorderButton()
    private let instantRecorder = ShortcutRecorderButton()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "TextPolisher Shortcuts"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show() {
        syncFromSettings()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Global shortcuts")
        title.font = .boldSystemFont(ofSize: 14)

        let hint = NSTextField(wrappingLabelWithString:
            "Click a field and press a new combination. It must include ⌘, ⌥, or ⌃. "
            + "Press Esc to cancel or Delete to keep the current one.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        selectionRecorder.onChange = { [weak self] shortcut in
            self?.settings.polishSelectionShortcut = shortcut
        }
        instantRecorder.onChange = { [weak self] shortcut in
            self?.settings.polishInstantShortcut = shortcut
        }

        let grid = NSGridView(views: [
            [makeLabel("Polish & preview:"), selectionRecorder],
            [makeLabel("Polish & replace now:"), instantRecorder],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        restore.bezelStyle = .rounded

        let stack = NSStackView(views: [title, grid, hint, restore])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.setCustomSpacing(8, after: grid)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
        ])

        selectionRecorder.widthAnchor.constraint(equalToConstant: 170).isActive = true
        instantRecorder.widthAnchor.constraint(equalToConstant: 170).isActive = true
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    private func syncFromSettings() {
        selectionRecorder.shortcut = settings.polishSelectionShortcut
        instantRecorder.shortcut = settings.polishInstantShortcut
    }

    @objc private func restoreDefaults() {
        settings.polishSelectionShortcut = Settings.defaultPolishSelection
        settings.polishInstantShortcut = Settings.defaultPolishInstant
        syncFromSettings()
    }
}
