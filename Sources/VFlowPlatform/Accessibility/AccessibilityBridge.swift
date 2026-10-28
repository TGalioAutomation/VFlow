import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Bridge for interacting with macOS Accessibility APIs (AXUIElement).
public final class AccessibilityBridge: @unchecked Sendable {
    public static let shared = AccessibilityBridge()
    private var enabledManualAXPids: Set<pid_t> = []
    private let lock = NSLock()

    public init() {}

    /// Pure deterministic evaluator for whether a field's Accessibility metadata or value indicates a password / hidden-text field.
    public static func isSecureFieldMetadata(
        role: String?,
        subrole: String?,
        description: String?,
        placeholder: String?,
        value: String?,
        isSystemSecureInput: Bool = false
    ) -> Bool {
        if isSystemSecureInput {
            return true
        }
        if let r = role?.lowercased(), r.contains("secure") {
            return true
        }
        if let sr = subrole?.lowercased(), sr.contains("secure") {
            return true
        }

        let sensitiveKeywords = [
            "password", "mật khẩu", "mat khau", "passcode", "mã pin", "secret key", "hide text", "ẩn văn bản"
        ]
        for meta in [description, placeholder].compactMap({ $0?.lowercased() }) where !meta.isEmpty {
            if sensitiveKeywords.contains(where: { meta.contains($0) }) {
                return true
            }
        }

        if let val = value?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
            let bulletChars: Set<Character> = ["•", "●", "✱", "⚫", "◦", "▪"]
            if val.allSatisfy({ bulletChars.contains($0) }) {
                return true
            }
            if val.count >= 2 && val.allSatisfy({ $0 == "*" }) {
                return true
            }
        }
        return false
    }

    /// Returns true if macOS Secure Event Input is active or the currently focused UI element is a password / hidden-text field.
    public func isFocusedElementSecureOrHidden() -> Bool {
        if IsSecureEventInputEnabled() {
            return true
        }
        guard let element = focusedUIElement() else {
            return false
        }

        func readStringAttr(_ attr: String) -> String? {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success,
               let str = ref as? String {
                return str
            }
            return nil
        }

        let role = readStringAttr(kAXRoleAttribute)
        let subrole = readStringAttr(kAXSubroleAttribute)
        let roleDesc = readStringAttr(kAXRoleDescriptionAttribute)
        let desc = readStringAttr(kAXDescriptionAttribute) ?? readStringAttr(kAXTitleAttribute)
        let combinedDesc = [roleDesc, desc].compactMap { $0 }.joined(separator: " ")
        let placeholder = readStringAttr(kAXPlaceholderValueAttribute)
        let value = readStringAttr(kAXValueAttribute)

        return Self.isSecureFieldMetadata(
            role: role,
            subrole: subrole,
            description: combinedDesc,
            placeholder: placeholder,
            value: value,
            isSystemSecureInput: false
        )
    }

    /// Ensures Electron/Chromium apps expose their AX tree (AXManualAccessibility).
    public func ensureManualAccessibility(for pid: pid_t) {
        lock.lock()
        let alreadyEnabled = enabledManualAXPids.contains(pid)
        if !alreadyEnabled {
            enabledManualAXPids.insert(pid)
        }
        lock.unlock()

        if !alreadyEnabled {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
    }

    /// Checks if accessibility permission is granted. Optionally shows prompt.
    public func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: prompt as CFBoolean] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Obtains the frontmost application.
    public func frontmostApplication() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    /// Obtains the currently focused UI element from the frontmost application.
    public func focusedUIElement() -> AXUIElement? {
        guard let frontApp = frontmostApplication() else { return nil }
        let pid = frontApp.processIdentifier
        ensureManualAccessibility(for: pid)
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        if result == .success, let element = focusedElement, CFGetTypeID(element) == AXUIElementGetTypeID() {
            return (element as! AXUIElement)
        }

        // Fallback: system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()
        var systemFocused: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &systemFocused) == .success,
           let element = systemFocused,
           CFGetTypeID(element) == AXUIElementGetTypeID() {
            return (element as! AXUIElement)
        }

        return nil
    }

    /// Reads the selected text or text value of the focused element.
    public func readSelectedText(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
           let str = value as? String, !str.isEmpty {
            return str
        }
        return nil
    }

    /// Replaces the selected text in the focused element via Accessibility.
    public func writeSelectedText(_ text: String, to element: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    /// Reads the live full string value (kAXValueAttribute) from the currently focused text input element.
    public func readFocusedTextValue() -> String? {
        guard let element = focusedUIElement() else { return nil }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let str = value as? String {
            return str
        }
        return nil
    }

    /// Writes a new full string value (kAXValueAttribute) into the focused text input element if supported.
    public func writeFocusedFullText(_ text: String) -> Bool {
        guard let element = focusedUIElement() else { return false }
        let res = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return res == .success
    }

    /// Pure parsing helper to extract cursor context from any text and cursor offset, useful for unit tests and AX extraction.
    public static func extractContext(fullText rawFullText: String, cursorLocation: Int) -> FocusedTextContext {
        let rawNS = rawFullText as NSString
        let safeRawCursor = max(0, min(rawNS.length, cursorLocation))
        let rawPrefix = rawNS.substring(to: safeRawCursor)
        let mappedCursor = (rawPrefix.precomposedStringWithCanonicalMapping as NSString).length

        let fullText = rawFullText.precomposedStringWithCanonicalMapping
        let nsText = fullText as NSString
        let cursorUTF16 = max(0, min(nsText.length, mappedCursor))

        // Scan backwards for wordPrefix (characters touching cursor on the left)
        var prefixRangeLocation = cursorUTF16
        while prefixRangeLocation > 0 {
            let charRange = nsText.rangeOfComposedCharacterSequence(at: prefixRangeLocation - 1)
            let charStr = nsText.substring(with: charRange)
            if charStr.rangeOfCharacter(from: .whitespacesAndNewlines) != nil ||
               charStr.rangeOfCharacter(from: .punctuationCharacters) != nil {
                break
            }
            prefixRangeLocation = charRange.location
        }
        let wordPrefix = nsText.substring(with: NSRange(location: prefixRangeLocation, length: cursorUTF16 - prefixRangeLocation))

        // Scan forwards for wordSuffix (characters touching cursor on the right)
        var suffixRangeEnd = cursorUTF16
        while suffixRangeEnd < nsText.length {
            let charRange = nsText.rangeOfComposedCharacterSequence(at: suffixRangeEnd)
            let charStr = nsText.substring(with: charRange)
            if charStr.rangeOfCharacter(from: .whitespacesAndNewlines) != nil ||
               charStr.rangeOfCharacter(from: .punctuationCharacters) != nil {
                break
            }
            suffixRangeEnd = charRange.location + charRange.length
        }
        let wordSuffix = nsText.substring(with: NSRange(location: cursorUTF16, length: suffixRangeEnd - cursorUTF16))

        let wordAtCursor = wordPrefix + wordSuffix

        // Completed words before the cursor (all words strictly to the left of prefixRangeLocation)
        let leftOfWord = nsText.substring(to: prefixRangeLocation)
        let leftWords = leftOfWord
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        let wordBeforeCursor = leftWords.last ?? ""

        // Words after the cursor (all words strictly to the right of suffixRangeEnd)
        let rightOfWord = nsText.substring(from: suffixRangeEnd)
        let rightWords = rightOfWord
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        let wordAfterCursor = rightWords.first ?? ""

        return FocusedTextContext(
            fullText: fullText,
            cursorLocation: cursorUTF16,
            wordAtCursor: wordAtCursor,
            wordPrefix: wordPrefix,
            wordSuffix: wordSuffix,
            wordBeforeCursor: wordBeforeCursor,
            wordAfterCursor: wordAfterCursor,
            completedWordsBeforeCursor: leftWords
        )
    }

    /// Reads the full text AND cursor position from the focused UI element, extracting the exact word at the cursor,
    /// the preceding word, and the following word (even when editing in the middle of a sentence).
    public func readFocusedTextContext() -> FocusedTextContext? {
        guard let element = focusedUIElement() else { return nil }
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String else {
            return nil
        }

        let nsText = fullText as NSString
        var cursorUTF16 = nsText.length

        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let axVal = rangeRef,
           CFGetTypeID(axVal) == AXValueGetTypeID() {
            var cfRange = CFRange(location: 0, length: 0)
            if AXValueGetValue((axVal as! AXValue), .cfRange, &cfRange) {
                cursorUTF16 = max(0, min(nsText.length, cfRange.location))
            }
        }

        return Self.extractContext(fullText: fullText, cursorLocation: cursorUTF16)
    }
}

/// Snapshot of the focused text field's content and caret neighborhood.
public struct FocusedTextContext: Sendable {
    public let fullText: String
    public let cursorLocation: Int
    public let wordAtCursor: String
    public let wordPrefix: String
    public let wordSuffix: String
    public let wordBeforeCursor: String
    public let wordAfterCursor: String
    public let completedWordsBeforeCursor: [String]

    public init(
        fullText: String,
        cursorLocation: Int,
        wordAtCursor: String,
        wordPrefix: String = "",
        wordSuffix: String = "",
        wordBeforeCursor: String,
        wordAfterCursor: String,
        completedWordsBeforeCursor: [String]
    ) {
        self.fullText = fullText
        self.cursorLocation = cursorLocation
        self.wordAtCursor = wordAtCursor
        self.wordPrefix = wordPrefix
        self.wordSuffix = wordSuffix
        self.wordBeforeCursor = wordBeforeCursor
        self.wordAfterCursor = wordAfterCursor
        self.completedWordsBeforeCursor = completedWordsBeforeCursor
    }
}
