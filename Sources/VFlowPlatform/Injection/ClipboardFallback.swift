import Foundation
import AppKit
import CoreGraphics

/// Represents a backed up pasteboard item.
public struct PasteboardBackupItem: Sendable {
    public let typesAndData: [(type: String, data: Data)]
}

/// Fallback mechanism to inject text via simulated ⌘V with lossless pasteboard backup & restore.
public final class ClipboardFallback: @unchecked Sendable {
    public static let shared = ClipboardFallback()

    public init() {}

    /// Captures the current content of NSPasteboard.general.
    public func backupPasteboard() -> [PasteboardBackupItem] {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems else { return [] }

        var backup: [PasteboardBackupItem] = []
        for item in items {
            var itemData: [(type: String, data: Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData.append((type.rawValue, data))
                }
            }
            backup.append(PasteboardBackupItem(typesAndData: itemData))
        }
        return backup
    }

    /// Restores a previously captured pasteboard state.
    public func restorePasteboard(_ backup: [PasteboardBackupItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard !backup.isEmpty else { return }

        var newItems: [NSPasteboardItem] = []
        for backupItem in backup {
            let item = NSPasteboardItem()
            for entry in backupItem.typesAndData {
                item.setData(entry.data, forType: NSPasteboard.PasteboardType(entry.type))
            }
            newItems.append(item)
        }
        pasteboard.writeObjects(newItems)
    }

    /// Safely injects text by setting clipboard, firing ⌘V, and restoring the clipboard.
    public func injectWithPasteboard(_ text: String, completion: (@Sendable () -> Void)? = nil) {
        let backup = backupPasteboard()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Post synthetic ⌘V
        simulateCommandV()

        // Asynchronously restore pasteboard after short delay (50ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            self.restorePasteboard(backup)
            completion?()
        }
    }

    /// Simulates Cmd+V keystroke tagged with syntheticEventMarker so EventTapHook ignores them.
    public func simulateCommandV() {
        let src = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: KeyCodeMap.kVK_ANSI_V, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.setIntegerValueField(.eventSourceUserData, value: EventTapHook.syntheticEventMarker)

        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: KeyCodeMap.kVK_ANSI_V, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.setIntegerValueField(.eventSourceUserData, value: EventTapHook.syntheticEventMarker)

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
