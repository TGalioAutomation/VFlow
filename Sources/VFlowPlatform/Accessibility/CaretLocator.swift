import Foundation
import AppKit
import ApplicationServices

/// Locates the blinking caret coordinate on screen and calculates the anchor position for the Caret Pill HUD.
public final class CaretLocator: @unchecked Sendable {
    public static let shared = CaretLocator()

    public init() {}

    /// Pure geometric algorithm to compute the HUD frame relative to a caret rect and screen frame.
    public static func calculatePillFrame(
        caretRect: CGRect,
        pillSize: CGSize = CGSize(width: 385, height: 38),
        screenFrame: CGRect
    ) -> CGRect {
        // Horizontally center HUD over caret
        var originX = caretRect.midX - (pillSize.width / 2.0)

        // Clamp horizontal bounds within visible screen with 8px margin
        originX = max(screenFrame.minX + 8.0, min(originX, screenFrame.maxX - pillSize.width - 8.0))

        // Normal anchor: 10px above the caret (AppKit coordinates: higher Y = higher on screen)
        var originY = caretRect.maxY + 10.0

        // Screen top boundary check: if HUD would clip into menu bar / top edge, flip to 10px below caret
        if originY + pillSize.height > screenFrame.maxY - 4.0 {
            originY = caretRect.minY - pillSize.height - 10.0
        }

        // Clamp bottom boundary check
        if originY < screenFrame.minY + 8.0 {
            originY = screenFrame.minY + 8.0
        }

        return CGRect(origin: CGPoint(x: originX, y: originY), size: pillSize)
    }

    /// Finds the current screen coordinates of the active blinking caret.
    public func findCaretScreenRect() -> CGRect? {
        guard let focusedElement = AccessibilityBridge.shared.focusedUIElement() else {
            return fallbackRectFromMouse()
        }

        // 1. Try AXSelectedTextRange + AXBoundsForRangeParameterizedAttribute
        var rangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeVal = rangeValue,
           CFGetTypeID(rangeVal) == AXValueGetTypeID() {
            var textRange = CFRange()
            if AXValueGetValue(rangeVal as! AXValue, .cfRange, &textRange) {
                var boundsValue: CFTypeRef?
                let paramRange = rangeVal
                let result = AXUIElementCopyParameterizedAttributeValue(
                    focusedElement,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    paramRange,
                    &boundsValue
                )

                if result == .success, let boundsVal = boundsValue, CFGetTypeID(boundsVal) == AXValueGetTypeID() {
                    var rect = CGRect.zero
                    if AXValueGetValue(boundsVal as! AXValue, .cgRect, &rect),
                       rect.origin.x > 1.0, rect.origin.y > 1.0,
                       rect.width >= 0, rect.height > 0, rect.height < 120 {
                        return convertToAppKitCoordinates(rect)
                    }
                }
            }
        }

        // 2. Fallback: Element position and size (e.g. Electron / Chromium AXTextArea / AXTextField)
        // Never anchor to non-input containers like AXWebArea, AXWindow, or AXScrollArea!
        var roleRef: CFTypeRef?
        let roleStr: String = {
            if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleRef) == .success,
               let r = roleRef as? String {
                return r
            }
            return ""
        }()
        if roleStr != "AXWebArea" && roleStr != "AXWindow" && roleStr != "AXScrollArea" {
            var posValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute as CFString, &posValue) == .success,
               AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute as CFString, &sizeValue) == .success,
               let posVal = posValue, let sizeVal = sizeValue {
                var point = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
                AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
                if size.width > 0 && size.height > 0 && !(size.width > 600 && size.height > 320) {
                    let effectiveHeight = min(size.height, 48.0)
                    let rect = CGRect(origin: point, size: CGSize(width: min(size.width, 420.0), height: effectiveHeight))
                    return convertToAppKitCoordinates(rect)
                }
            }
        }

        // 3. Fallback: Mouse cursor
        return fallbackRectFromMouse()
    }

    private func fallbackRectFromMouse() -> CGRect {
        let mouseLoc = NSEvent.mouseLocation
        return CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 2.0, height: 16.0)
    }

    /// Converts AX coordinates (origin at top-left of primary screen) to AppKit coordinates (origin at bottom-left).
    private func convertToAppKitCoordinates(_ axRect: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return axRect }
        let screenHeight = primaryScreen.frame.height
        let appKitY = screenHeight - axRect.origin.y - axRect.height
        return CGRect(x: axRect.origin.x, y: appKitY, width: axRect.width, height: axRect.height)
    }
}
