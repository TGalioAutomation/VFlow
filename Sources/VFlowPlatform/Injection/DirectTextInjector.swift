import Foundation
import AppKit
import ApplicationServices

/// Handles direct text replacement via macOS Accessibility APIs.
public struct DirectTextInjector: Sendable {
    /// Injects text directly into the currently focused element. Returns true if successful.
    public static func inject(_ text: String) -> Bool {
        guard let focused = AccessibilityBridge.shared.focusedUIElement() else {
            return false
        }
        return AccessibilityBridge.shared.writeSelectedText(text, to: focused)
    }
}
