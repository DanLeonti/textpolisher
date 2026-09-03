import AppKit
import Carbon.HIToolbox

/// Registers system-wide hotkeys via the Carbon RegisterEventHotKey API, which
/// fire regardless of which app is frontmost. Supports multiple shortcuts; the
/// shared event handler dispatches to the matching handler by hotkey id.
final class HotKeyManager {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private var handlers: [UInt32: @Sendable () -> Void] = [:]
    private var nextID: UInt32 = 1

    fileprivate static var shared: HotKeyManager?

    init() {
        HotKeyManager.shared = self
        installEventHandler()
    }

    /// Registers a global shortcut. `keyCode` is a `kVK_` virtual key code;
    /// `modifiers` is a Carbon modifier mask (e.g. `cmdKey | optionKey`).
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping @Sendable () -> Void) {
        let id = nextID
        nextID += 1
        handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x53545048), id: id) // 'STPH'
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }

    /// Registers a global shortcut from a `KeyboardShortcut`.
    func register(_ shortcut: KeyboardShortcut, handler: @escaping @Sendable () -> Void) {
        register(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers, handler: handler)
    }

    /// Tears down every registered shortcut so the set can be rebuilt (e.g. when
    /// the user changes their shortcut preferences).
    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
        nextID = 1
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let id = hotKeyID.id
            DispatchQueue.main.async {
                HotKeyManager.shared?.handlers[id]?()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandlerRef)
    }

    deinit {
        for ref in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
