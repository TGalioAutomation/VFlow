import Foundation
import CoreGraphics
import AppKit
import VFlowCore

/// System-wide keyboard event tap hook using CGEventTap to intercept and rewrite keystrokes.
public final class EventTapHook: @unchecked Sendable {
    public static let shared = EventTapHook()

    /// Magic marker attached to synthetic events emitted by VFlow so our tap never re-intercepts them.
    public static let syntheticEventMarker: Int64 = 0x56464C57 // "VFLW"

    public let engine: VietnameseInputEngine
    private var _isEnabled: Bool = true
    public var isEnabled: Bool {
        get { lock.withLock { _isEnabled } }
        set { lock.withLock { _isEnabled = newValue } }
    }

    private var _lastActiveVietnameseMethod: InputMethod = .telex
    public var lastActiveVietnameseMethod: InputMethod {
        get { lock.withLock { _lastActiveVietnameseMethod } }
        set { lock.withLock { _lastActiveVietnameseMethod = newValue } }
    }

    private var _suggestionAcceptShortcut: SuggestionAcceptShortcut = .doubleTab
    public var suggestionAcceptShortcut: SuggestionAcceptShortcut {
        get { lock.withLock { _suggestionAcceptShortcut } }
        set { lock.withLock { _suggestionAcceptShortcut = newValue } }
    }

    public var onInputMethodChanged: (@Sendable (InputMethod) -> Void)?
    public var onTypingStateChanged: (@Sendable (_ currentWord: String, _ rawWord: String, _ sentenceWords: [String], _ inputMethod: InputMethod, _ fullSentenceText: String, _ wordAfterCursor: String) -> Void)?
    public var onSelectSuggestionShortcut: (@Sendable (_ index: Int) -> Bool)?
    public var onHUDMouseDown: (@Sendable (_ screenPoint: CGPoint) -> Bool)?
    public var hasActiveSuggestions: (@Sendable () -> Bool)?
    public var onDoubleTabArmedChanged: (@Sendable (_ isArmed: Bool) -> Void)?
    public var onDismissHUD: (@Sendable () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let privateEventSource = CGEventSource(stateID: .privateState)
    private var heldKeyCodes: Set<CGKeyCode> = []
    private var swallowedKeyCodes: Set<CGKeyCode> = []
    private var lastPhysicalKeyCode: CGKeyCode = 0xFFFF
    private var lastWordBeforeMouseReset: String = ""
    private var lastMouseResetTime: Date = .distantPast
    private var lastTypingActivityTime: Date = .distantPast
    private var swallowingHUDMouseClick: Bool = false
    private var lastTabPressTime: Date = .distantPast
    private var pendingSingleTabWorkItem: DispatchWorkItem?
    private var isCursorKnownAtEnd: Bool = true
    private var lastBoundaryWasSpace: Bool = false
    private let lock = NSLock()
    private let logPath = "/tmp/vflow_keylog.log"

    // MARK: - Thread-Safe State Accessors
    private func recordKeyDown(_ keycode: CGKeyCode) {
        _ = lock.withLock {
            heldKeyCodes.insert(keycode)
        }
    }

    private func handleKeyUp(_ keycode: CGKeyCode) -> Bool {
        lock.withLock {
            heldKeyCodes.remove(keycode)
            return swallowedKeyCodes.remove(keycode) != nil
        }
    }

    private func swallowKey(_ keycode: CGKeyCode) {
        _ = lock.withLock {
            swallowedKeyCodes.insert(keycode)
        }
    }

    private func setLastPhysicalKey(_ keycode: CGKeyCode) {
        lock.withLock {
            lastPhysicalKeyCode = keycode
        }
    }

    private func recordMouseReset(word: String) {
        lock.withLock {
            lastWordBeforeMouseReset = word
            lastMouseResetTime = Date()
        }
    }

    private func clearMouseReset() {
        lock.withLock {
            lastWordBeforeMouseReset = ""
        }
    }

    private func recordTypingActivity() {
        lock.withLock {
            lastTypingActivityTime = Date()
        }
    }

    private func isWithinTypingActivityWindow(seconds: TimeInterval = 6.0) -> Bool {
        lock.withLock {
            Date().timeIntervalSince(lastTypingActivityTime) < seconds
        }
    }

    private func canTriggerSuggestionShortcut() -> Bool {
        if let hasActive = hasActiveSuggestions {
            return hasActive()
        }
        return isWithinTypingActivityWindow(seconds: 3600.0)
    }

    private func recordCompletedBoundary(char: Character, currentWord: String) {
        let punctuationSet: Set<Character> = [".", ",", "!", "?", ";", ":"]
        if char == " " {
            TypingBuffer.shared.appendWord(currentWord)
            clearMouseReset()
            lock.withLock { lastBoundaryWasSpace = true }
        } else if punctuationSet.contains(char) {
            if !currentWord.isEmpty {
                TypingBuffer.shared.appendWord(currentWord + String(char))
            } else {
                TypingBuffer.shared.appendPunctuation(char)
            }
            clearMouseReset()
            lock.withLock { lastBoundaryWasSpace = false }
        } else {
            lock.withLock { lastBoundaryWasSpace = false }
        }
    }

    public func cancelPendingDoubleTab(flushSingleTab: Bool = false) {
        let (pendingItem, wasArmed): (DispatchWorkItem?, Bool) = lock.withLock {
            let item = pendingSingleTabWorkItem
            let armed = (item != nil || lastTabPressTime != .distantPast)
            pendingSingleTabWorkItem = nil
            lastTabPressTime = .distantPast
            return (item, armed)
        }
        pendingItem?.cancel()
        if wasArmed {
            onDoubleTabArmedChanged?(false)
            // Never emit a focus-stealing synthetic Tab when disarming an active Suggestion HUD Double-Tab
            _ = flushSingleTab
        }
    }

    /// Evaluates whether a keyDown event triggers the configured Suggestion Accept Shortcut
    /// (`Tab+Tab`, `Single Tab`, `Right Arrow →`, `Shift+Return ⇧↩`, or `⌥1/⌥2/⌥3`).
    /// Returns `true` if the keystroke was consumed.
    public func handleSuggestionShortcutKeyDown(
        keycode: CGKeyCode,
        flags: CGEventFlags,
        isAutorepeat: Bool = false,
        replaySingleTabOnTimeout: Bool = true
    ) -> Bool {
        // 1. Always support Option + 1 / 2 / 3 (⌥1, ⌥2, ⌥3) in all modes
        if flags.contains(.maskAlternate) && !flags.contains(.maskCommand) && !flags.contains(.maskControl) {
            let suggestionIdx: Int? = {
                switch keycode {
                case KeyCodeMap.kVK_ANSI_1: return 0
                case KeyCodeMap.kVK_ANSI_2: return 1
                case KeyCodeMap.kVK_ANSI_3: return 2
                default: return nil
                }
            }()
            if let idx = suggestionIdx, onSelectSuggestionShortcut?(idx) == true {
                cancelPendingDoubleTab(flushSingleTab: false)
                return true
            }
        }

        // If any non-Tab key is pressed while a first Tab is armed, disarm the pending Double-Tab
        if keycode != KeyCodeMap.kVK_Tab {
            cancelPendingDoubleTab(flushSingleTab: false)
        }

        guard canTriggerSuggestionShortcut() else {
            return false
        }

        let mode = suggestionAcceptShortcut
        let hasNoPrimaryModifiers = !flags.contains(.maskCommand) && !flags.contains(.maskControl) && !flags.contains(.maskAlternate)

        switch mode {
        case .doubleTab:
            guard keycode == KeyCodeMap.kVK_Tab && hasNoPrimaryModifiers else { return false }
            if isAutorepeat {
                return true
            }
            let now = Date()
            let elapsed = lock.withLock { now.timeIntervalSince(lastTabPressTime) }
            if elapsed <= 0.90 {
                // 2nd Tab press within 900ms -> Accept Suggestion #1!
                cancelPendingDoubleTab(flushSingleTab: false)
                if onSelectSuggestionShortcut?(0) == true {
                    logDiagnostic("DOUBLE_TAB_ACCEPTED elapsedMs=\(Int(elapsed * 1000))")
                    return true
                }
                return false
            } else {
                // 1st Tab press while HUD has active suggestions -> Arm Double-Tab & hold for 900ms without stealing focus
                lock.withLock {
                    pendingSingleTabWorkItem?.cancel()
                    lastTabPressTime = now
                }
                onDoubleTabArmedChanged?(true)
                if replaySingleTabOnTimeout {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        self.lock.withLock {
                            self.pendingSingleTabWorkItem = nil
                            self.lastTabPressTime = .distantPast
                        }
                        self.onDoubleTabArmedChanged?(false)
                    }
                    lock.withLock {
                        pendingSingleTabWorkItem = work
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.90, execute: work)
                }
                return true
            }

        case .singleTab:
            guard keycode == KeyCodeMap.kVK_Tab && hasNoPrimaryModifiers && !flags.contains(.maskShift) else { return false }
            return onSelectSuggestionShortcut?(0) == true

        case .rightArrow:
            guard keycode == 0x7C && hasNoPrimaryModifiers && !flags.contains(.maskShift) else { return false }
            return onSelectSuggestionShortcut?(0) == true

        case .shiftReturn:
            guard keycode == KeyCodeMap.kVK_Return && flags.contains(.maskShift) && hasNoPrimaryModifiers else { return false }
            return onSelectSuggestionShortcut?(0) == true

        case .optionNumbers:
            return false
        }
    }

    /// Emits a single synthetic key press with `syntheticEventMarker` so VFlow's tap passes it straight through.
    public func postSyntheticKey(_ keycode: CGKeyCode, flags: CGEventFlags = []) {
        let src = privateEventSource ?? CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    /// Finds the start and end boundary indices of the sentence clause around the cursor.
    public static func findClauseBounds(in text: String, cursorLocation: Int) -> (startIndex: Int, endIndex: Int) {
        let ns = text as NSString
        let len = ns.length
        guard len > 0 else { return (0, 0) }
        let safeCursor = max(0, min(len, cursorLocation))

        // Find clause start by scanning backwards from cursor for newline or sentence terminator (. ! ?)
        var start = safeCursor
        while start > 0 {
            let prevChar = ns.character(at: start - 1)
            if prevChar == 0x0A || prevChar == 0x0D { // \n or \r
                break
            }
            if prevChar == 0x2E || prevChar == 0x21 || prevChar == 0x3F { // . ! ?
                break
            }
            start -= 1
        }
        // Skip leading spaces of the clause
        while start < safeCursor && ns.character(at: start) == 0x20 {
            start += 1
        }

        // Find clause end by scanning forwards from cursor for newline or sentence terminator (. ! ?)
        var end = safeCursor
        while end < len {
            let nextChar = ns.character(at: end)
            if nextChar == 0x0A || nextChar == 0x0D { // \n or \r
                break
            }
            if nextChar == 0x2E || nextChar == 0x21 || nextChar == 0x3F { // . ! ?
                break
            }
            end += 1
        }
        // Trim trailing spaces before clause end
        while end > start && ns.character(at: end - 1) == 0x20 {
            end -= 1
        }

        return (start, end)
    }

    public init(engine: VietnameseInputEngine = VietnameseInputEngine()) {
        self.engine = engine
    }

    public func logDiagnostic(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logPath),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }

    /// Returns whether the system-wide CGEventTap is currently active and enabled.
    public var isTapActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    /// Starts the event tap on the main run loop.
    @discardableResult
    public func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let existingTap = eventTap {
            if !CGEvent.tapIsEnabled(tap: existingTap) {
                CGEvent.tapEnable(tap: existingTap, enable: true)
            }
            return CGEvent.tapIsEnabled(tap: existingTap)
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Hook at .cgSessionEventTap first (matching OpenKey on macOS), fallback to .cghidEventTap
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let hook = Unmanaged<EventTapHook>.fromOpaque(refcon).takeUnretainedValue()
                return hook.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) ?? CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let hook = Unmanaged<EventTapHook>.fromOpaque(refcon).takeUnretainedValue()
                return hook.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let validTap = tap else {
            return false
        }

        self.eventTap = validTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validTap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: validTap, enable: true)
        logDiagnostic("EVENT_TAP_STARTED pid=\(ProcessInfo.processInfo.processIdentifier) enabled=\(CGEvent.tapIsEnabled(tap: validTap))")

        return true
    }

    /// Stops and disables the event tap.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 1. Always re-enable tap if disabled by macOS timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // 2. CRITICAL: Ignore synthetic events emitted by VFlow itself!
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        // 3. Handle mouse clicks on the floating Caret Pill HUD without stealing focus or resetting the engine
        if type == .leftMouseUp {
            let wasSwallowing = lock.withLock {
                let cur = swallowingHUDMouseClick
                swallowingHUDMouseClick = false
                return cur
            }
            if wasSwallowing {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseDown || type == .rightMouseDown {
            cancelPendingDoubleTab(flushSingleTab: false)
            if type == .leftMouseDown {
                let screenPoint = NSEvent.mouseLocation
                if onHUDMouseDown?(screenPoint) == true {
                    lock.withLock { swallowingHUDMouseClick = true }
                    recordTypingActivity()
                    logDiagnostic("HUD_MOUSE_CLICK at=(\(Int(screenPoint.x)),\(Int(screenPoint.y)))")
                    return nil
                }
            }
            if !engine.formattedWord.isEmpty {
                recordMouseReset(word: engine.formattedWord)
            }
            lock.withLock { isCursorKnownAtEnd = false }
            engine.reset()
            onDismissHUD?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if !AccessibilityBridge.shared.isFocusedElementEditableTextInput() {
                    TypingBuffer.shared.clear()
                    self?.onDismissHUD?()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp {
            if keycode == KeyCodeMap.kVK_Space {
                PushToTalkMonitor.shared.handleOptionSpaceKeyUp()
            }
            if handleKeyUp(keycode) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        recordKeyDown(keycode)

        // Push-to-Talk / Tap-to-Talk Voice Dictation via Option + Space (⌥Space)
        // Swallow the keystroke so macOS does not insert a non-breaking space (\u{00A0}) into the active text field.
        if flags.contains(.maskAlternate) && !flags.contains(.maskCommand) && !flags.contains(.maskControl) && keycode == KeyCodeMap.kVK_Space {
            swallowKey(keycode)
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                PushToTalkMonitor.shared.handleOptionSpaceKeyDown()
            }
            return nil
        }

        // Quick global toggle VI ⇄ EN via Option + Z (⌥Z)
        if flags.contains(.maskAlternate) && !flags.contains(.maskCommand) && !flags.contains(.maskControl) && keycode == KeyCodeMap.kVK_ANSI_Z {
            engine.reset()
            swallowKey(keycode)
            if engine.inputMethod == .off {
                engine.inputMethod = lastActiveVietnameseMethod
            } else {
                lastActiveVietnameseMethod = engine.inputMethod
                engine.inputMethod = .off
            }
            onInputMethodChanged?(engine.inputMethod)
            notifyTypingState()
            logDiagnostic("TOGGLE_METHOD -> \(engine.inputMethod.rawValue)")
            return nil
        }

        // Secure / Password / Hidden Text Field OR Non-Editable Browser/App Element Guard:
        // Never transform Telex/VNI, never display Caret Pill HUD, and never intercept keys when not focused in an editable text box.
        if AccessibilityBridge.shared.isFocusedElementSecureOrHidden() ||
           !AccessibilityBridge.shared.isFocusedElementEditableTextInput() {
            cancelPendingDoubleTab(flushSingleTab: false)
            engine.reset()
            clearMouseReset()
            TypingBuffer.shared.clear()
            onDismissHUD?()
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Quick suggestion selection via Option + 1 / 2 / 3 (⌥1, ⌥2, ⌥3) or customizable primary shortcut (Tab+Tab, Tab, →, Shift+Enter)
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if handleSuggestionShortcutKeyDown(
            keycode: keycode,
            flags: flags,
            isAutorepeat: isAutorepeat,
            replaySingleTabOnTimeout: true
        ) {
            swallowKey(keycode)
            return nil
        }

        // Pass through if Command, Control, or Option is held
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            if flags.contains(.maskCommand) {
                TypingBuffer.shared.clear()
                clearMouseReset()
            }
            engine.reset()
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Arrow keys & navigation keys reset word buffer
        if keycode == 0x7B || keycode == 0x7C || keycode == 0x7D || keycode == 0x7E ||
           keycode == 0x73 || keycode == 0x77 || keycode == 0x74 || keycode == 0x79 ||
           keycode == 0x75 {
            if keycode == 0x7B || keycode == 0x7E || keycode == 0x73 || keycode == 0x74 {
                lock.withLock { isCursorKnownAtEnd = false }
            } else if keycode == 0x77 || keycode == 0x79 {
                lock.withLock { isCursorKnownAtEnd = true }
            }
            engine.reset()
            clearMouseReset()
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Check Backspace
        if keycode == KeyCodeMap.kVK_Delete {
            let wasWordEmpty = engine.formattedWord.isEmpty
            let res = engine.handleBackspace()
            if wasWordEmpty {
                TypingBuffer.shared.popLastWord()
            }
            logDiagnostic("BACKSPACE consumed=\(res.consumed) bs=\(res.backspaceCount) rep='\(res.replacementText)' word='\(res.currentWord)' raw='\(engine.rawString)'")
            notifyTypingState()
            if res.consumed {
                swallowKey(keycode)
                if res.backspaceCount > 0 {
                    postBackspaces(res.backspaceCount, proxy: proxy)
                }
                if !res.replacementText.isEmpty {
                    postUnicodeString(res.replacementText, avoidingKeyCode: keycode, proxy: proxy)
                }
                return nil
            }
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Check Tab (when no active suggestion consumed it above)
        if keycode == KeyCodeMap.kVK_Tab {
            engine.reset()
            clearMouseReset()
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Check Return / Escape
        if keycode == KeyCodeMap.kVK_Escape {
            engine.reset()
            clearMouseReset()
            onDismissHUD?()
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        if keycode == KeyCodeMap.kVK_Return {
            let pendingWord = engine.formattedWord
            engine.reset()
            clearMouseReset()
            if !pendingWord.isEmpty {
                TypingBuffer.shared.appendWord(pendingWord)
            }
            if !flags.contains(.maskShift) {
                onDismissHUD?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    if let val = AccessibilityBridge.shared.readFocusedTextValue(),
                       val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        TypingBuffer.shared.clear()
                    }
                }
            }
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Map keycode to character
        let shift = flags.contains(.maskShift) || flags.contains(.maskAlphaShift)
        guard let char = KeyCodeMap.character(for: keycode, shift: shift) else {
            logDiagnostic("UNMAPPED kc=\(keycode)")
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        let result = engine.processKey(char)
        logDiagnostic("KEY char='\(char)' kc=\(keycode) consumed=\(result.consumed) bs=\(result.backspaceCount) rep='\(result.replacementText)' word='\(result.currentWord)' raw='\(engine.rawString)'")

        if result.consumed {
            swallowKey(keycode)
            if result.backspaceCount > 0 {
                postBackspaces(result.backspaceCount, proxy: proxy)
            }
            if !result.replacementText.isEmpty {
                postUnicodeString(result.replacementText, avoidingKeyCode: keycode, proxy: proxy)
            }
            recordCompletedBoundary(char: char, currentWord: result.currentWord)
            setLastPhysicalKey(keycode)
            notifyTypingState()
            return nil // Swallow original raw keystroke
        } else if !result.replacementText.isEmpty {
            swallowKey(keycode)
            if result.backspaceCount > 0 {
                postBackspaces(result.backspaceCount, proxy: proxy)
            }
            postUnicodeString(result.replacementText, avoidingKeyCode: keycode, proxy: proxy)
            recordCompletedBoundary(char: char, currentWord: result.currentWord)
            setLastPhysicalKey(keycode)
            notifyTypingState()
            return nil
        }

        recordCompletedBoundary(char: char, currentWord: result.currentWord)

        setLastPhysicalKey(keycode)
        notifyTypingState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
            self?.notifyTypingState()
        }
        return Unmanaged.passUnretained(event)
    }

    /// Reads the focused text context and resolves cursorLocation when Chromium/Electron contenteditable
    /// elements report cursorLocation == 0 or a child-node offset while the user is typing at the end.
    private func readResolvedTextContext() -> FocusedTextContext? {
        guard let rawCtx = AccessibilityBridge.shared.readFocusedTextContext() else {
            return nil
        }
        let nsFull = rawCtx.fullText as NSString
        guard nsFull.length > 0 else {
            lock.withLock { isCursorKnownAtEnd = true }
            return rawCtx
        }
        if rawCtx.cursorLocation >= nsFull.length {
            lock.withLock { isCursorKnownAtEnd = true }
            return rawCtx
        }

        let trimmedFull = rawCtx.fullText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentFormatted = engine.formattedWord.lowercased()
        let lastBufferedWord = (TypingBuffer.shared.recentWords().last ?? "")
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()

        let isBogusZeroCursor = (rawCtx.cursorLocation == 0) &&
            (!currentFormatted.isEmpty || !lastBufferedWord.isEmpty || lock.withLock { isCursorKnownAtEnd })

        let matchesEndByCurrentWord = !currentFormatted.isEmpty &&
            trimmedFull.hasSuffix(currentFormatted) &&
            rawCtx.wordPrefix.lowercased() != currentFormatted

        let matchesEndByBufferedWord = currentFormatted.isEmpty &&
            !lastBufferedWord.isEmpty &&
            trimmedFull.hasSuffix(lastBufferedWord) &&
            rawCtx.wordBeforeCursor.lowercased() != lastBufferedWord &&
            rawCtx.wordAtCursor.lowercased() != lastBufferedWord

        if isBogusZeroCursor || matchesEndByCurrentWord || matchesEndByBufferedWord || lock.withLock({ isCursorKnownAtEnd }) {
            lock.withLock { isCursorKnownAtEnd = true }
            return AccessibilityBridge.extractContext(fullText: rawCtx.fullText, cursorLocation: nsFull.length)
        }
        return rawCtx
    }

    /// Broadcasts the current composing word and sentence context to the Caret Pill HUD.
    public func notifyTypingState() {
        if AccessibilityBridge.shared.isFocusedElementSecureOrHidden() ||
           !AccessibilityBridge.shared.isFocusedElementEditableTextInput() {
            engine.reset()
            clearMouseReset()
            TypingBuffer.shared.clear()
            onDismissHUD?()
            return
        }
        recordTypingActivity()
        var currentWord = engine.formattedWord
        let rawWord = engine.rawString
        var fullSentenceText = ""
        var wordAfterCursor = ""

        if let ctx = readResolvedTextContext() {
            // Preserve the ENTIRE input box text (including multiple sentences separated by '.' and multi-line '\n' paragraphs)
            fullSentenceText = ctx.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            wordAfterCursor = ctx.wordAfterCursor
            // Cursor Word Sync: if user is editing inside an existing word (e.g. "duoc|"),
            // ctx.wordAtCursor has the full word ("duoc") even if engine only saw the last keystroke ("c")!
            if ctx.wordAtCursor.count > currentWord.count {
                currentWord = ctx.wordAtCursor
            } else if currentWord.count > ctx.wordAtCursor.count && !currentWord.isEmpty {
                // Target web/Electron app hasn't flushed the latest keystroke into AXValue yet (e.g. AXValue has "da" while engine has "dau"):
                // Synchronize fullSentenceText so the HUD and AI Engine never lag by 1 character!
                if !ctx.wordAtCursor.isEmpty && fullSentenceText.hasSuffix(ctx.wordAtCursor) {
                    fullSentenceText = String(fullSentenceText.dropLast(ctx.wordAtCursor.count)) + currentWord
                } else if ctx.wordAtCursor.isEmpty {
                    fullSentenceText = fullSentenceText.isEmpty ? currentWord : (fullSentenceText + " " + currentWord)
                }
            }
            if !currentWord.isEmpty {
                recordMouseReset(word: currentWord)
            }
            TypingBuffer.shared.syncWithLiveText(ctx.fullText, currentComposingWord: currentWord)
            let words = ctx.completedWordsBeforeCursor
            onTypingStateChanged?(currentWord, rawWord, words, engine.inputMethod, fullSentenceText, wordAfterCursor)
            return
        }

        let words = TypingBuffer.shared.recentWords()
        fullSentenceText = (words + (currentWord.isEmpty ? [] : [currentWord])).joined(separator: " ")
        let method = engine.inputMethod
        onTypingStateChanged?(currentWord, rawWord, words, method, fullSentenceText, wordAfterCursor)
    }

    /// Applies a selected suggestion item directly into the active text field.
    public func applySuggestion(_ item: SuggestionItem) {
        let ctx = readResolvedTextContext()
        let liveText = ctx?.fullText

        let activeWord: String = {
            if !item.targetWordToReplace.isEmpty {
                return item.targetWordToReplace
            }
            if let cursorWord = ctx?.wordAtCursor, !cursorWord.isEmpty {
                return cursorWord
            }
            if !engine.formattedWord.isEmpty {
                return engine.formattedWord
            }
            let (savedWord, savedTime) = lock.withLock {
                (lastWordBeforeMouseReset, lastMouseResetTime)
            }
            if Date().timeIntervalSince(savedTime) < 1.5 && !savedWord.isEmpty {
                if let live = liveText, live.hasSuffix(" ") {
                    return ""
                }
                return savedWord
            }
            if item.replaceCurrentWord,
               let lastBuf = TypingBuffer.shared.recentWords().last,
               !lastBuf.isEmpty,
               liveText?.hasSuffix(" ") != true,
               item.text.lowercased().hasPrefix(lastBuf.lowercased() + " ") {
                return lastBuf
            }
            return ""
        }()

        // Case 1: Full input box / multi-sentence polish (✨) — always replaces via synthetic keystrokes (100% compatible with Electron, Chrome, AppKit, SwiftUI)
        if item.kind == .aiPolish {
            let targetInserted = item.text + (item.text.hasSuffix(" ") ? "" : " ")
            if let ctx = ctx, !ctx.fullText.isEmpty {
                TypingBuffer.shared.recordForUndo(ctx.fullText)
                let nsFull = ctx.fullText as NSString
                let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
                let leftSub = nsFull.substring(to: safeCursor)
                let rightSub = nsFull.substring(from: safeCursor)
                let rightTrimmed = rightSub.trimmingCharacters(in: .whitespacesAndNewlines)

                if rightTrimmed.isEmpty {
                    let rightTrailingSpacesCount = rightSub.count
                    if rightTrailingSpacesCount > 0 {
                        postForwardDeletes(rightTrailingSpacesCount)
                    }
                    let delta = VietnameseInputEngine.minimalDelta(from: leftSub, to: targetInserted)
                    if delta.backspaces > 0 {
                        postBackspaces(delta.backspaces)
                    }
                    if !delta.replacement.isEmpty {
                        postUnicodeString(delta.replacement)
                    }
                    logDiagnostic("APPLY_AI_POLISH mode=delta bs=\(delta.backspaces) repLen=\(delta.replacement.count) fullLen=\(nsFull.length)")
                } else {
                    if leftSub.count > 0 {
                        postBackspaces(leftSub.count)
                    }
                    if rightSub.count > 0 {
                        postForwardDeletes(rightSub.count)
                    }
                    postUnicodeString(targetInserted)
                    logDiagnostic("APPLY_AI_POLISH mode=midCursor leftBS=\(leftSub.count) rightDel=\(rightSub.count) repLen=\(targetInserted.count)")
                }
            } else {
                let currentSentence = TypingBuffer.shared.currentSentence()
                let fullDisplayed: String = {
                    if activeWord.isEmpty {
                        return currentSentence
                    }
                    if currentSentence.lowercased().hasSuffix(activeWord.lowercased()) {
                        return currentSentence
                    }
                    return currentSentence.isEmpty ? activeWord : "\(currentSentence) \(activeWord)"
                }()
                if !fullDisplayed.isEmpty {
                    TypingBuffer.shared.recordForUndo(fullDisplayed)
                    let hasTrailingSpace = activeWord.isEmpty && lock.withLock { lastBoundaryWasSpace }
                    let displayedWithTrailing = fullDisplayed + (hasTrailingSpace ? " " : "")
                    let delta = VietnameseInputEngine.minimalDelta(from: displayedWithTrailing, to: targetInserted)
                    if delta.backspaces > 0 {
                        postBackspaces(delta.backspaces)
                    }
                    if !delta.replacement.isEmpty {
                        postUnicodeString(delta.replacement)
                    }
                    logDiagnostic("APPLY_AI_POLISH mode=bufferFallback bs=\(delta.backspaces) repLen=\(delta.replacement.count)")
                } else {
                    postUnicodeString(targetInserted)
                    logDiagnostic("APPLY_AI_POLISH mode=directInsert repLen=\(targetInserted.count)")
                }
            }
            clearMouseReset()
            engine.reset()
            TypingBuffer.shared.clear()
            for tok in item.text.components(separatedBy: .whitespaces) where !tok.isEmpty {
                TypingBuffer.shared.appendWord(tok)
            }
            lock.withLock {
                lastBoundaryWasSpace = true
                isCursorKnownAtEnd = true
            }
            notifyTypingState()
            return
        }

        // Case 2: Replace the just-completed word (right after Space, e.g. "ko " -> "không ")
        if item.replaceLastCompletedWord && !item.targetWordToReplace.isEmpty {
            let trailingWhitespaceCount: Int = {
                if let ctx = ctx {
                    let nsFull = ctx.fullText as NSString
                    let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
                    let leftStr = nsFull.substring(to: safeCursor)
                    var count = 0
                    for ch in leftStr.reversed() {
                        if ch.isWhitespace {
                            count += 1
                        } else {
                            break
                        }
                    }
                    return max(1, count)
                }
                return 1
            }()
            let bsCount = item.targetWordToReplace.count + trailingWhitespaceCount
            postBackspaces(bsCount)
            postUnicodeString(item.text + " ")
            logDiagnostic("APPLY_LAST_WORD target='\(item.targetWordToReplace)' rep='\(item.text)' bs=\(bsCount)")
            clearMouseReset()
            engine.reset()
            TypingBuffer.shared.replaceLastWord(with: item.text)
            lock.withLock { lastBoundaryWasSpace = true }
            notifyTypingState()
            return
        }

        // Case 3: Replace the word at the cursor (e.g. "duoc|" -> "được " or mid-word "du|oc" -> "được")
        if item.replaceCurrentWord && !activeWord.isEmpty {
            let ctxMatchesActiveWord: Bool = {
                guard let ctx = ctx else { return false }
                if ctx.wordAtCursor.lowercased() == activeWord.lowercased() && !ctx.wordPrefix.isEmpty {
                    return true
                }
                if !ctx.wordPrefix.isEmpty && activeWord.lowercased().hasPrefix(ctx.wordPrefix.lowercased()) {
                    return true
                }
                return false
            }()
            let leftCount = ctxMatchesActiveWord ? (ctx?.wordPrefix.count ?? activeWord.count) : activeWord.count
            let rightCount = ctxMatchesActiveWord ? (ctx?.wordSuffix.count ?? 0) : 0

            if leftCount > 0 {
                postBackspaces(leftCount)
            }
            if rightCount > 0 {
                postForwardDeletes(rightCount)
            }

            let hasSpaceAfterCursor: Bool = {
                if ctxMatchesActiveWord, let ctx = ctx {
                    let nsFull = ctx.fullText as NSString
                    let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
                    let suffixLength = (ctx.wordSuffix as NSString).length
                    let afterWordIndex = min(nsFull.length, safeCursor + suffixLength)
                    if afterWordIndex < nsFull.length {
                        let afterChar = nsFull.character(at: afterWordIndex)
                        // 0x20 (space), 0x0A (\n), 0x0D (\r), 0x2E (.), 0x2C (,), 0x21 (!), 0x3F (?), 0x3B (;), 0x3A (:)
                        if afterChar == 0x20 || afterChar == 0x0A || afterChar == 0x0D ||
                           afterChar == 0x2E || afterChar == 0x2C || afterChar == 0x21 ||
                           afterChar == 0x3F || afterChar == 0x3B || afterChar == 0x3A {
                            return true
                        }
                    }
                    let rightStr = nsFull.substring(from: afterWordIndex)
                    return rightStr.hasPrefix(" ")
                }
                return false
            }()
            postUnicodeString(item.text + (hasSpaceAfterCursor ? "" : " "))
            logDiagnostic("APPLY_CURRENT_WORD active='\(activeWord)' rep='\(item.text)' leftBS=\(leftCount) rightDel=\(rightCount)")
            clearMouseReset()
            engine.reset()
            for tok in item.text.components(separatedBy: .whitespaces) where !tok.isEmpty {
                TypingBuffer.shared.appendWord(tok)
            }
            lock.withLock { lastBoundaryWasSpace = !hasSpaceAfterCursor }
            notifyTypingState()
            return
        }

        // Case 4: Append next word(s) or insert missing bridge word — ensure clean spacing & gap normalization
        var deleteLeftSpaces = 0
        var deleteRightSpaces = 0
        var needsLeadingSpace = false
        var needsTrailingSpace = true

        if let ctx = ctx {
            let nsFull = ctx.fullText as NSString
            let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
            let leftStr = nsFull.substring(to: safeCursor)
            let rightStr = nsFull.substring(from: safeCursor)

            let cleanLeftLower = leftStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanItemLower = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanItemLower.isEmpty && (cleanLeftLower == cleanItemLower || cleanLeftLower.hasSuffix(" " + cleanItemLower)) {
                logDiagnostic("APPLY_NEXT_WORD_SKIPPED_DUPLICATE text='\(item.text)'")
                clearMouseReset()
                engine.reset()
                notifyTypingState()
                return
            }

            // Count trailing spaces on left
            var leftSpaces = 0
            for ch in leftStr.reversed() {
                if ch == " " { leftSpaces += 1 } else { break }
            }

            // Count leading spaces on right
            var rightSpaces = 0
            for ch in rightStr {
                if ch == " " { rightSpaces += 1 } else { break }
            }

            if safeCursor == 0 {
                // R2-BUG-08: Start of document boundary: NEVER insert a leading space!
                needsLeadingSpace = false
                if rightSpaces > 0 {
                    deleteRightSpaces = rightSpaces - 1
                    needsTrailingSpace = false
                } else {
                    needsTrailingSpace = true
                }
            } else if leftSpaces == 0 {
                // Touching a word on left: needs 1 leading space
                needsLeadingSpace = true
                if rightSpaces > 1 {
                    deleteRightSpaces = rightSpaces - 1
                }
                needsTrailingSpace = rightSpaces == 0
            } else {
                // At least 1 space on left: delete excess so exactly 1 space precedes
                if leftSpaces > 1 {
                    deleteLeftSpaces = leftSpaces - 1
                }
                needsLeadingSpace = false
                if rightSpaces > 0 {
                    deleteRightSpaces = rightSpaces - 1
                    needsTrailingSpace = false
                } else {
                    needsTrailingSpace = true
                }
            }

            let firstRightChar = rightStr.trimmingCharacters(in: .whitespaces).first
            let isPunctuationAfter = firstRightChar.map { ",.?!;:)]}".contains($0) } ?? false
            if isPunctuationAfter {
                needsTrailingSpace = false
            }

            let lastLeftChar = leftStr.last
            if lastLeftChar == "\n" || lastLeftChar == "\r" {
                needsLeadingSpace = false
            }
        } else {
            needsLeadingSpace = !activeWord.isEmpty
            needsTrailingSpace = true
        }

        if deleteLeftSpaces > 0 {
            postBackspaces(deleteLeftSpaces)
        }
        if deleteRightSpaces > 0 {
            postForwardDeletes(deleteRightSpaces)
        }

        let textToInsert = (needsLeadingSpace ? " " : "") + item.text + (needsTrailingSpace ? " " : "")
        postUnicodeString(textToInsert)
        logDiagnostic("APPLY_NEXT_WORD text='\(item.text)' insertedLen=\(textToInsert.count)")
        clearMouseReset()
        engine.reset()
        for tok in item.text.components(separatedBy: .whitespaces) where !tok.isEmpty {
            TypingBuffer.shared.appendWord(tok)
        }
        notifyTypingState()
    }

    /// Injects finalized voice dictation text directly at the active cursor position and returns the number of characters inserted.
    @discardableResult
    public func injectVoiceTranscript(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        var needsLeadingSpace = false
        if let ctx = AccessibilityBridge.shared.readFocusedTextContext(),
           !ctx.fullText.isEmpty {
            let nsFull = ctx.fullText as NSString
            let cursorLoc = min(nsFull.length, max(0, ctx.cursorLocation))
            if cursorLoc > 0 {
                let prevChar = nsFull.character(at: cursorLoc - 1)
                if prevChar != 0x20 && prevChar != 0x0A && prevChar != 0x0D && prevChar != 0x09 {
                    needsLeadingSpace = true
                }
            }
        } else if !engine.formattedWord.isEmpty {
            needsLeadingSpace = true
        }

        let textToInsert = (needsLeadingSpace ? " " : "") + trimmed + " "
        clearMouseReset()
        engine.reset()
        postUnicodeString(textToInsert)

        for tok in trimmed.components(separatedBy: .whitespaces) where !tok.isEmpty {
            TypingBuffer.shared.appendWord(tok)
        }
        recordTypingActivity()
        notifyTypingState()
        logDiagnostic("VOICE_INJECT len=\(textToInsert.count) text='\(trimmed)'")
        return textToInsert.count
    }

    /// Selects a valid ANSI virtual key (< 128) that does not collide with any currently held physical key or the preceding vowel key.
    private func safeUnicodeVirtualKey(avoiding triggerKeyCode: CGKeyCode) -> CGKeyCode {
        lock.withLock {
            let candidates: [CGKeyCode] = [0, 31, 14, 32, 34, 1, 2, 4, 5]
            for vk in candidates {
                if !heldKeyCodes.contains(vk) && vk != lastPhysicalKeyCode && vk != triggerKeyCode {
                    return vk
                }
            }
            return (triggerKeyCode == 0 || lastPhysicalKeyCode == 0) ? 31 : 0
        }
    }

    /// Emits forward-delete (kVK_ForwardDelete = 0x75) keystrokes to erase characters to the right of the cursor.
    public func postForwardDeletes(_ count: Int, proxy: CGEventTapProxy? = nil) {
        guard count > 0 else { return }
        let src = privateEventSource ?? CGEventSource(stateID: .privateState)
        let forwardDeleteVK: CGKeyCode = 0x75
        for _ in 0..<count {
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: forwardDeleteVK, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: forwardDeleteVK, keyDown: false) else {
                continue
            }
            down.flags.remove([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift])
            up.flags.remove([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift])
            down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
            up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)

            if let proxy = proxy {
                down.tapPostEvent(proxy)
                up.tapPostEvent(proxy)
            } else {
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }
    }

    /// Emits backspace keystrokes to erase characters from the active field without re-triggering VFlow's tap.
    public func postBackspaces(_ count: Int, proxy: CGEventTapProxy? = nil) {
        guard count > 0 else { return }
        let src = privateEventSource ?? CGEventSource(stateID: .privateState)
        for idx in 0..<count {
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: KeyCodeMap.kVK_Delete, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: KeyCodeMap.kVK_Delete, keyDown: false) else {
                continue
            }
            down.flags.remove([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift])
            up.flags.remove([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift])
            down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
            up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)

            if let proxy = proxy {
                down.tapPostEvent(proxy)
                up.tapPostEvent(proxy)
            } else {
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
                if count > 12 && (idx + 1) % 10 == 0 {
                    usleep(450)
                }
            }
        }
        if proxy == nil && count > 10 {
            usleep(900)
        }
    }

    /// Emits a unicode string into the active field without re-triggering VFlow's tap,
    /// chunking into <= 20 UniChar blocks to prevent CoreGraphics truncation.
    public func postUnicodeString(_ text: String, avoidingKeyCode: CGKeyCode = 0xFFFF, proxy: CGEventTapProxy? = nil) {
        guard !text.isEmpty else { return }
        let src = privateEventSource ?? CGEventSource(stateID: .privateState)
        let utf16Chars = Array(text.utf16)
        let vk = safeUnicodeVirtualKey(avoiding: avoidingKeyCode)
        let chunkSize = 20

        for start in stride(from: 0, to: utf16Chars.count, by: chunkSize) {
            if start > 0 && proxy == nil {
                usleep(850)
            }
            let end = min(start + chunkSize, utf16Chars.count)
            let chunk = Array(utf16Chars[start..<end])

            guard let down = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: false) else {
                continue
            }

            down.flags.remove([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift])
            up.flags.remove([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift])
            down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
            up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)

            down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)

            if let proxy = proxy {
                down.tapPostEvent(proxy)
                up.tapPostEvent(proxy)
            } else {
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }
    }
}
