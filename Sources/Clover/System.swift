import AppKit
import CloverCore

/// The macOS side effects of the panel: Finder and dialogs.
@MainActor
enum System {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func confirm(_ message: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除").hasDestructiveAction = true
        alert.addButton(withTitle: "取消")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func alert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        NSApp.activate()
        alert.runModal()
    }
}
