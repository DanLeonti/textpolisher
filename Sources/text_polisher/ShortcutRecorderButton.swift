import AppKit
import Carbon.HIToolbox

/// A button that records a global keyboard shortcut. Click it, then press the
/// desired key combination; Escape cancels and Delete clears. The combination
/// must include Command, Option, or Control to be accepted.
final class ShortcutRecorderButton: NSButton {
    var shortcut: KeyboardShortcut? {
        didSet { updateTitle() }
    }

    /// Called with the newly recorded shortcut.
    var onChange: ((KeyboardShortcut) -> Void)?

    private var isRecording = false {
        didSet { updateTitle() }
    }
    private var monitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        updateTitle()
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.type == .keyDown { self.handleKeyDown(event) }
            return nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            stopRecording()
        case kVK_Delete, kVK_ForwardDelete:
            stopRecording()
        default:
            let candidate = KeyboardShortcut(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: KeyboardShortcut.carbonModifiers(from: event.modifierFlags))
            guard candidate.isValid else {
                NSSound.beep()
                return
            }
            shortcut = candidate
            stopRecording()
            onChange?(candidate)
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { stopRecording() }
        return super.resignFirstResponder()
    }

    private func updateTitle() {
        if isRecording {
            title = "Type shortcut…"
        } else {
            title = shortcut?.displayString ?? "Click to record"
        }
    }
}
