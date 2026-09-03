import AppKit
import SwiftUI

/// A non-activating floating panel that can become key (so keyboard shortcuts
/// such as Return/Escape work) without activating our app. The originating app
/// (e.g. Slack) stays the frontmost application; focus is explicitly returned to
/// it before the replacement is injected.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosts the SwiftUI overlay in a non-activating floating panel so the
/// originating app stays frontmost (keeping its text selection and focus intact
/// for the replace step).
@MainActor
final class OverlayController {
    private var panel: NSPanel?

    func show(viewModel: OverlayViewModel) {
        close()

        let defaultSize = NSSize(width: 480, height: 360)
        let hosting = NSHostingView(rootView: OverlayView(viewModel: viewModel))
        hosting.frame = NSRect(origin: .zero, size: defaultSize)

        let panel = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting

        // Size to the SwiftUI content, but only after layout and never to a
        // collapsed size (fittingSize can be zero before the view is laid out).
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 200 { size.width = defaultSize.width }
        if size.height < 160 { size.height = defaultSize.height }
        panel.setContentSize(size)

        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
        // Make the panel key so keyboard shortcuts (Return = Replace,
        // Escape = Cancel) work. Because it is a non-activating panel, this does
        // not activate our app or change which app is frontmost.
        panel.makeKey()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - panel.frame.height - 12)
        if origin.x + panel.frame.width > visible.maxX {
            origin.x = visible.maxX - panel.frame.width - 8
        }
        origin.x = max(origin.x, visible.minX + 8)
        if origin.y < visible.minY {
            origin.y = visible.minY + 8
        }
        if origin.y + panel.frame.height > visible.maxY {
            origin.y = visible.maxY - panel.frame.height - 8
        }
        panel.setFrameOrigin(origin)
    }
}
