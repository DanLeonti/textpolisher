import AppKit

/// Helpers for reading, snapshotting, and restoring the general pasteboard so we
/// never permanently clobber the user's clipboard during capture/replace.
enum PasteboardHelper {
    static func snapshot() -> [NSPasteboardItem] {
        let pasteboard = NSPasteboard.general
        var copies: [NSPasteboardItem] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            copies.append(copy)
        }
        return copies
    }

    static func restore(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    static func setString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    static func string() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    static var changeCount: Int {
        NSPasteboard.general.changeCount
    }
}
