import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Bridge for interacting with macOS Accessibility APIs (AXUIElement).
public final class AccessibilityBridge: @unchecked Sendable {
    public static let shared = AccessibilityBridge()
    private var enabledManualAXPids: Set<pid_t> = []
    private let lock = NSLock()

    private struct CacheEntry {
        let value: Bool
        let timestamp: Date
        let pid: pid_t?
    }
    private var cachedIsSecure: CacheEntry?
    private var cachedIsBlocked: CacheEntry?
    private var isBackgroundProbeInFlight = false
    private let axProbeQueue = DispatchQueue(label: "com.apexdev.vflow.axProbe", qos: .userInitiated)
    private let cacheTTL: TimeInterval = 0.45

    /// Inspection hook for test verification: returns true if a valid, unexpired secure cache entry exists.
    var isSecureCacheActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = cachedIsSecure else { return false }
        return Date().timeIntervalSince(entry.timestamp) < cacheTTL
    }

    /// Inspection hook for test verification: returns true if a valid, unexpired blocked-typing cache entry exists.
    var isBlockedCacheActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = cachedIsBlocked else { return false }
        return Date().timeIntervalSince(entry.timestamp) < cacheTTL
    }

    /// Non-blocking cache lookup for the real-time `CGEventTap` callback (< 0.005ms, zero Mach IPC on the keystroke thread).
    /// Returns the latest cached `(isSecure, isBlocked)` for the active frontmost app and triggers a coalesced background probe when expired.
    public func fastCachedSecurityAndBlockStatus() -> (isSecure: Bool, isBlocked: Bool) {
        let currentPid = frontmostApplication()?.processIdentifier
        let now = Date()

        let (secVal, blkVal, needsRefresh): (Bool, Bool, Bool) = lock.withLock {
            let validSec = cachedIsSecure.flatMap { ($0.pid == currentPid && now.timeIntervalSince($0.timestamp) < cacheTTL) ? $0.value : nil }
            let validBlk = cachedIsBlocked.flatMap { ($0.pid == currentPid && now.timeIntervalSince($0.timestamp) < cacheTTL) ? $0.value : nil }
            if let s = validSec, let b = validBlk {
                return (s, b, false)
            }
            let fallbackSec = (cachedIsSecure?.pid == currentPid) ? (cachedIsSecure?.value ?? false) : false
            let fallbackBlk = (cachedIsBlocked?.pid == currentPid) ? (cachedIsBlocked?.value ?? false) : false
            if isBackgroundProbeInFlight {
                return (fallbackSec, fallbackBlk, false)
            }
            isBackgroundProbeInFlight = true
            return (fallbackSec, fallbackBlk, true)
        }

        if needsRefresh {
            axProbeQueue.async { [weak self] in
                guard let self = self else { return }
                let (sec, blk) = self.computeCombinedSecurityAndBlockStatus()
                let stamp = Date()
                let probePid = self.frontmostApplication()?.processIdentifier
                self.lock.lock()
                self.cachedIsSecure = CacheEntry(value: sec, timestamp: stamp, pid: probePid)
                self.cachedIsBlocked = CacheEntry(value: blk, timestamp: stamp, pid: probePid)
                self.isBackgroundProbeInFlight = false
                self.lock.unlock()
            }
        }

        return (secVal, blkVal)
    }

    /// Invalidates in-memory security and control caches (e.g. on application switch or mouse clicks).
    public func invalidateCache() {
        lock.lock()
        cachedIsSecure = nil
        cachedIsBlocked = nil
        lock.unlock()
    }

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

    /// Returns true if the currently focused UI element is a verified password / hidden-text field,
    /// or if system-wide Secure Event Input is active from an authentic terminal or security application.
    /// Standard text inputs (AXTextField, AXTextArea, AXWebArea, AXGroup) ignore background leaked secure input.
    public func isFocusedElementSecureOrHidden() -> Bool {
        let frontApp = frontmostApplication()
        let currentPid = frontApp?.processIdentifier

        lock.lock()
        if let cache = cachedIsSecure,
           cache.pid == currentPid,
           Date().timeIntervalSince(cache.timestamp) < cacheTTL {
            let res = cache.value
            lock.unlock()
            return res
        }
        lock.unlock()

        let secure = computeIsFocusedElementSecureOrHidden()

        lock.lock()
        cachedIsSecure = CacheEntry(
            value: secure,
            timestamp: Date(),
            pid: currentPid
        )
        lock.unlock()

        return secure
    }

    private func computeCombinedSecurityAndBlockStatus() -> (isSecure: Bool, isBlocked: Bool) {
        guard let element = focusedUIElement() else {
            return (isSystemSecureInputActiveForTerminal(), false)
        }
        let role = readAXString(element, kAXRoleAttribute)
        let isBlocked = Self.isNonTextInteractiveControl(role: role)
        if isBlocked {
            return (false, true)
        }
        let isSecure = evaluateElementSecurity(element: element, prefetchedRole: role)
        return (isSecure, false)
    }

    private func isSystemSecureInputActiveForTerminal() -> Bool {
        guard IsSecureEventInputEnabled() else { return false }
        let securityAppBundles: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "net.kovidgoyal.kitty",
            "com.mitchellh.ghostty",
            "org.alacritty",
            "com.apple.SecurityAgent",
            "com.apple.loginwindow",
            "com.apple.ScreenSaver.Engine"
        ]
        if let bundleId = frontmostApplication()?.bundleIdentifier,
           securityAppBundles.contains(bundleId) {
            return true
        }
        return false
    }

    private func readAXString(_ element: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success,
           let str = ref as? String {
            return str
        }
        return nil
    }

    private func computeIsFocusedElementSecureOrHidden() -> Bool {
        guard let element = focusedUIElement() else {
            return isSystemSecureInputActiveForTerminal()
        }
        let role = readAXString(element, kAXRoleAttribute)
        return evaluateElementSecurity(element: element, prefetchedRole: role)
    }

    private func evaluateElementSecurity(element: AXUIElement, prefetchedRole: String?) -> Bool {
        let role = prefetchedRole
        if let r = role?.lowercased(), r.contains("secure") {
            return true
        }

        let subrole = readAXString(element, kAXSubroleAttribute)
        if let sr = subrole?.lowercased(), sr.contains("secure") {
            return true
        }

        let roleDesc = readAXString(element, kAXRoleDescriptionAttribute)
        let desc = readAXString(element, kAXDescriptionAttribute) ?? readAXString(element, kAXTitleAttribute)
        let combinedDesc = [roleDesc, desc].compactMap { $0 }.joined(separator: " ")
        let placeholder = readAXString(element, kAXPlaceholderValueAttribute)

        // Avoid false-negative lock release race while reading AX inside isFocusedElementSecureOrHidden vs fastCachedSecurityAndBlockStatus
        // (everything here is synchronous on axProbeQueue when using fast path)
        // or fields with > 64 characters — prevents slow synchronous Mach IPC buffer copies while typing.
        var shortValue: String? = nil
        if role == "AXTextField" {
            var numCharsRef: CFTypeRef?
            let charCount: Int? = (AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString, &numCharsRef) == .success)
                ? (numCharsRef as? NSNumber)?.intValue
                : nil
            if charCount.map({ $0 <= 64 }) ?? true {
                shortValue = readAXString(element, kAXValueAttribute)
            }
        }

        // 1. Evaluate element metadata FIRST
        if Self.isSecureFieldMetadata(
            role: role,
            subrole: subrole,
            description: combinedDesc,
            placeholder: placeholder,
            value: shortValue,
            isSystemSecureInput: false
        ) {
            return true
        }

        // 2. If focused element has standard text or web roles without secure attributes,
        // return false (ignoring background leaked IsSecureEventInputEnabled()).
        let standardTextOrWebRoles: Set<String> = [
            "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXWebArea", "AXGroup"
        ]
        if let r = role, standardTextOrWebRoles.contains(r) {
            return false
        }

        // 3. For any other non-standard element or system modal:
        return isSystemSecureInputActiveForTerminal()
    }

    /// Pure deterministic evaluator for whether an Accessibility element's metadata represents an editable text input.
    /// Rejects non-editable browser/document containers (`AXWebArea`, `AXLink`, `AXButton`, `AXWindow`, etc.)
    /// unless `contenteditable` (`AXEditable == true`) is explicitly active.
    public static func isEditableElementMetadata(
        role: String?,
        subrole: String? = nil,
        isEditableAttr: Bool? = nil,
        isValueSettable: Bool = false,
        isSelectedTextSettable: Bool = false,
        ancestorIsEditable: Bool = false
    ) -> Bool {
        guard let rawRole = role, !rawRole.isEmpty else {
            return false
        }

        // 1. Standard native & web text input roles (<input>, <textarea>, Omnibox, NSTextField, NSTextView)
        let standardTextRoles: Set<String> = [
            "AXTextField",
            "AXTextArea",
            "AXComboBox",
            "AXSearchField"
        ]
        if standardTextRoles.contains(rawRole) {
            if isEditableAttr == false && !isValueSettable && !isSelectedTextSettable {
                return false
            }
            return true
        }

        if let sr = subrole, (sr == "AXSearchField" || sr == "AXTextField") {
            return true
        }

        // 2. Explicit contenteditable / rich-editor flag on self or ancestor (Notion, Gmail, Slack, Antigravity, Google Docs)
        if isEditableAttr == true || ancestorIsEditable {
            return true
        }

        // 3. Browser webpage root (AXWebArea) and non-text UI controls are NEVER editable unless AXEditable == true above
        let nonEditableRoles: Set<String> = [
            "AXWebArea",
            "AXWindow",
            "AXApplication",
            "AXScrollArea",
            "AXLink",
            "AXButton",
            "AXRadioButton",
            "AXCheckBox",
            "AXPopUpButton",
            "AXMenuButton",
            "AXTabGroup",
            "AXToolbar",
            "AXMenu",
            "AXMenuBar",
            "AXMenuItem",
            "AXImage",
            "AXHeading",
            "AXList",
            "AXTable",
            "AXOutline",
            "AXSlider",
            "AXScrollBar",
            "AXSplitter",
            "AXColorWell"
        ]
        if nonEditableRoles.contains(rawRole) {
            return false
        }

        // 4. Generic containers or text nodes (AXGroup, AXStaticText) are only editable if their value or selected text is settable
        if isValueSettable || isSelectedTextSettable {
            return true
        }

        return false
    }

    /// Evaluates if the element role represents a verified non-text interactive control
    /// where typing has no semantic meaning.
    public static func isNonTextInteractiveControl(role: String?) -> Bool {
        guard let rawRole = role, !rawRole.isEmpty else { return false }
        let nonTextRoles: Set<String> = [
            "AXButton",
            "AXRadioButton",
            "AXCheckBox",
            "AXPopUpButton",
            "AXMenuButton",
            "AXSlider",
            "AXScrollBar",
            "AXSplitter",
            "AXColorWell"
        ]
        return nonTextRoles.contains(rawRole)
    }

    /// Defensive typing block evaluator: only blocks if the focused element is a verified non-text interactive control
    /// (AXButton, AXSlider, AXPopUpButton, AXCheckBox, AXRadioButton).
    /// Does NOT block for nil, AXWebArea, AXGroup, or standard text fields (permissive fallback).
    public func isBlockedFromTyping() -> Bool {
        let frontApp = frontmostApplication()
        let currentPid = frontApp?.processIdentifier

        lock.lock()
        if let cache = cachedIsBlocked,
           cache.pid == currentPid,
           Date().timeIntervalSince(cache.timestamp) < cacheTTL {
            let res = cache.value
            lock.unlock()
            return res
        }
        lock.unlock()

        let blocked = computeIsBlockedFromTyping()

        lock.lock()
        cachedIsBlocked = CacheEntry(
            value: blocked,
            timestamp: Date(),
            pid: currentPid
        )
        lock.unlock()

        return blocked
    }

    private func computeIsBlockedFromTyping() -> Bool {
        guard let element = focusedUIElement() else {
            return false // Permissive fallback on nil (never block typing)
        }
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let roleStr = roleRef as? String {
            return Self.isNonTextInteractiveControl(role: roleStr)
        }
        return false // Permissive fallback if role cannot be read
    }

    /// Returns true if the focused element is considered an editable text input or permissive container (AXWebArea, AXGroup, nil).
    /// Returns false only if positively verified as a non-text interactive control.
    public func isFocusedElementEditableTextInput() -> Bool {
        return !isBlockedFromTyping()
    }

    /// Ensures Electron/Chromium apps expose their AX tree (`AXManualAccessibility` & `AXEnhancedUserInterface`).
    public func ensureManualAccessibility(for pid: pid_t) {
        lock.lock()
        let alreadyEnabled = enabledManualAXPids.contains(pid)
        if !alreadyEnabled {
            enabledManualAXPids.insert(pid)
        }
        lock.unlock()

        if !alreadyEnabled {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 0.02)
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
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
        AXUIElementSetMessagingTimeout(appElement, 0.02)

        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        if result == .success, let element = focusedElement, CFGetTypeID(element) == AXUIElementGetTypeID() {
            let axEl = (element as! AXUIElement)
            AXUIElementSetMessagingTimeout(axEl, 0.02)
            return axEl
        }

        // Fallback: system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.02)
        var systemFocused: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &systemFocused) == .success,
           let element = systemFocused,
           CFGetTypeID(element) == AXUIElementGetTypeID() {
            let axEl = (element as! AXUIElement)
            AXUIElementSetMessagingTimeout(axEl, 0.02)
            return axEl
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
        var currentParent: AXUIElement = element
        for _ in 0..<8 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentParent, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parentVal = parentRef,
                  CFGetTypeID(parentVal) == AXUIElementGetTypeID() else {
                break
            }
            let parentEl = parentVal as! AXUIElement
            var roleRef: CFTypeRef?
            let parentRole = (AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &roleRef) == .success)
                ? (roleRef as? String ?? "")
                : ""
            if parentRole == "AXWindow" || parentRole == "AXApplication" || parentRole == "AXWebArea" {
                break
            }
            var parentValueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(parentEl, kAXValueAttribute as CFString, &parentValueRef) == .success,
               let str = parentValueRef as? String {
                return str
            }
            currentParent = parentEl
        }
        return nil
    }

    /// Writes a new full string value (kAXValueAttribute) into the focused text input element if supported.
    public func writeFocusedFullText(_ text: String) -> Bool {
        guard let element = focusedUIElement() else { return false }
        let res = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return res == .success
    }

    /// Directly inserts text at the current cursor/selection of the focused text input via Accessibility APIs
    /// (`kAXSelectedTextAttribute` or `kAXValueAttribute` splicing) as a deterministic fallback.
    @discardableResult
    public func insertTextIntoFocusedElement(_ text: String) -> Bool {
        guard !text.isEmpty, let element = focusedUIElement() else { return false }

        func tryInsert(on el: AXUIElement) -> Bool {
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(el, kAXSelectedTextAttribute as CFString, &settable) == .success,
               settable.boolValue {
                if AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
                    return true
                }
            }
            var valSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &valSettable) == .success,
               valSettable.boolValue {
                var valueRef: CFTypeRef?
                let existing = (AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valueRef) == .success)
                    ? (valueRef as? String ?? "")
                    : ""
                let nsExisting = existing as NSString
                var insertLoc = nsExisting.length
                var insertLen = 0
                var rangeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
                   let axVal = rangeRef,
                   CFGetTypeID(axVal) == AXValueGetTypeID() {
                    var cfRange = CFRange(location: 0, length: 0)
                    if AXValueGetValue((axVal as! AXValue), .cfRange, &cfRange) {
                        insertLoc = max(0, min(nsExisting.length, cfRange.location))
                        insertLen = max(0, min(nsExisting.length - insertLoc, cfRange.length))
                    }
                }
                let updated = nsExisting.replacingCharacters(in: NSRange(location: insertLoc, length: insertLen), with: text)
                if AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, updated as CFTypeRef) == .success {
                    var newCursor = CFRange(location: insertLoc + (text as NSString).length, length: 0)
                    if let newRangeVal = AXValueCreate(.cfRange, &newCursor) {
                        _ = AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, newRangeVal)
                    }
                    return true
                }
            }
            return false
        }

        if tryInsert(on: element) {
            return true
        }

        var currentParent: AXUIElement = element
        for _ in 0..<8 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentParent, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parentVal = parentRef,
                  CFGetTypeID(parentVal) == AXUIElementGetTypeID() else {
                break
            }
            let parentEl = parentVal as! AXUIElement
            var roleRef: CFTypeRef?
            let parentRole = (AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &roleRef) == .success)
                ? (roleRef as? String ?? "")
                : ""
            if parentRole == "AXWindow" || parentRole == "AXApplication" || parentRole == "AXWebArea" {
                break
            }
            if tryInsert(on: parentEl) {
                return true
            }
            currentParent = parentEl
        }
        return false
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
        guard isFocusedElementEditableTextInput(),
              let element = focusedUIElement() else { return nil }

        func extractValueAndRange(from el: AXUIElement) -> (String, Int)? {
            var valueRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valueRef) == .success,
                  let text = valueRef as? String else {
                return nil
            }
            let ns = text as NSString
            var cursor = ns.length
            var rangeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
               let axVal = rangeRef,
               CFGetTypeID(axVal) == AXValueGetTypeID() {
                var cfRange = CFRange(location: 0, length: 0)
                if AXValueGetValue((axVal as! AXValue), .cfRange, &cfRange) {
                    cursor = max(0, min(ns.length, cfRange.location))
                }
            }
            return (text, cursor)
        }

        if let (fullText, cursorUTF16) = extractValueAndRange(from: element) {
            return Self.extractContext(fullText: fullText, cursorLocation: cursorUTF16)
        }

        // Fallback for rich contenteditable editors where focusedUIElement() is a child span/group
        // and the full text value is held on the parent AXTextArea / AXEditable container
        var currentParent: AXUIElement = element
        for _ in 0..<8 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentParent, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parentVal = parentRef,
                  CFGetTypeID(parentVal) == AXUIElementGetTypeID() else {
                break
            }
            let parentEl = parentVal as! AXUIElement
            var roleRef: CFTypeRef?
            let parentRole = (AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &roleRef) == .success)
                ? (roleRef as? String ?? "")
                : ""
            if parentRole == "AXWindow" || parentRole == "AXApplication" || parentRole == "AXWebArea" {
                break
            }
            if let (fullText, cursorUTF16) = extractValueAndRange(from: parentEl) {
                return Self.extractContext(fullText: fullText, cursorLocation: cursorUTF16)
            }
            currentParent = parentEl
        }

        return nil
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
