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
    public var onInputMethodChanged: (@Sendable (InputMethod) -> Void)?
    public var onTypingStateChanged: (@Sendable (_ currentWord: String, _ rawWord: String, _ sentenceWords: [String], _ inputMethod: InputMethod, _ fullSentenceText: String, _ wordAfterCursor: String) -> Void)?
    public var onSelectSuggestionShortcut: (@Sendable (_ index: Int) -> Bool)?
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

        // 3. Reset word buffer on mouse clicks (cursor moved) & refresh HUD for new cursor position
        if type == .leftMouseDown || type == .rightMouseDown {
            if !engine.formattedWord.isEmpty {
                recordMouseReset(word: engine.formattedWord)
            }
            engine.reset()
            if isWithinTypingActivityWindow(seconds: 12.0) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                    self?.notifyTypingState()
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

        // Quick suggestion selection via Option + 1 / 2 / 3 (⌥1, ⌥2, ⌥3)
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
                swallowKey(keycode)
                return nil
            }
        }

        guard engine.inputMethod != .off else {
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
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

        // Check Tab to accept Suggestion #1 (⇥) when HUD is active within 6s of typing
        if keycode == KeyCodeMap.kVK_Tab {
            if isWithinTypingActivityWindow(seconds: 6.0),
               onSelectSuggestionShortcut?(0) == true {
                swallowKey(keycode)
                return nil
            }
            engine.reset()
            clearMouseReset()
            setLastPhysicalKey(keycode)
            return Unmanaged.passUnretained(event)
        }

        // Check Return / Escape
        if keycode == KeyCodeMap.kVK_Return || keycode == KeyCodeMap.kVK_Escape {
            engine.reset()
            clearMouseReset()
            TypingBuffer.shared.clear()
            onDismissHUD?()
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
            if char == " " {
                TypingBuffer.shared.appendWord(result.currentWord)
                clearMouseReset()
            }
            setLastPhysicalKey(keycode)
            notifyTypingState()
            return nil // Swallow original raw keystroke
        } else if !result.replacementText.isEmpty {
            swallowKey(keycode)
            if result.backspaceCount > 0 {
                postBackspaces(result.backspaceCount, proxy: proxy)
            }
            postUnicodeString(result.replacementText, avoidingKeyCode: keycode, proxy: proxy)
            TypingBuffer.shared.appendWord(result.currentWord)
            clearMouseReset()
            setLastPhysicalKey(keycode)
            notifyTypingState()
            return nil
        }

        if char == " " {
            TypingBuffer.shared.appendWord(result.currentWord)
            clearMouseReset()
        }

        setLastPhysicalKey(keycode)
        notifyTypingState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
            self?.notifyTypingState()
        }
        return Unmanaged.passUnretained(event)
    }

    /// Broadcasts the current composing word and sentence context to the Caret Pill HUD.
    public func notifyTypingState() {
        recordTypingActivity()
        var currentWord = engine.formattedWord
        let rawWord = engine.rawString
        var fullSentenceText = ""
        var wordAfterCursor = ""

        if let ctx = AccessibilityBridge.shared.readFocusedTextContext() {
            let (cStart, cEnd) = Self.findClauseBounds(in: ctx.fullText, cursorLocation: ctx.cursorLocation)
            let ns = ctx.fullText as NSString
            let safeStart = max(0, min(ns.length, cStart))
            let safeLen = max(0, min(ns.length - safeStart, cEnd - safeStart))
            fullSentenceText = ns.substring(with: NSRange(location: safeStart, length: safeLen))
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
        let method = engine.inputMethod
        onTypingStateChanged?(currentWord, rawWord, words, method, fullSentenceText, wordAfterCursor)
    }

    /// Applies a selected suggestion item directly into the active text field.
    public func applySuggestion(_ item: SuggestionItem) {
        let ctx = AccessibilityBridge.shared.readFocusedTextContext()
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
            return ""
        }()

        // Case 1: Full sentence polish (✨) — bounded to the active clause to prevent document wiping
        if item.kind == .aiPolish {
            if let ctx = ctx, !ctx.fullText.isEmpty {
                TypingBuffer.shared.recordForUndo(ctx.fullText)
                let nsFull = ctx.fullText as NSString
                let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
                let (clauseStart, clauseEnd) = Self.findClauseBounds(in: ctx.fullText, cursorLocation: safeCursor)

                let safeStart = max(0, min(safeCursor, clauseStart))
                let leftLen = max(0, safeCursor - safeStart)
                let rightLen = max(0, min(nsFull.length - safeCursor, clauseEnd - safeCursor))

                let leftSub = nsFull.substring(with: NSRange(location: safeStart, length: leftLen))
                let rightSub = nsFull.substring(with: NSRange(location: safeCursor, length: rightLen))
                let leftCharsCount = leftSub.count
                let rightCharsCount = rightSub.count

                if leftCharsCount > 0 {
                    postBackspaces(leftCharsCount)
                }
                if rightCharsCount > 0 {
                    postForwardDeletes(rightCharsCount)
                }

                let hasSpaceOrPunctuationAfter: Bool = {
                    if clauseEnd < nsFull.length {
                        let afterChar = nsFull.character(at: clauseEnd)
                        if afterChar == 0x20 || afterChar == 0x0A || afterChar == 0x0D ||
                           afterChar == 0x2E || afterChar == 0x21 || afterChar == 0x3F || afterChar == 0x2C {
                            return true
                        }
                    }
                    return false
                }()
                postUnicodeString(item.text + (hasSpaceOrPunctuationAfter ? "" : " "))
            } else {
                let currentSentence = TypingBuffer.shared.currentSentence()
                let fullDisplayed = activeWord.isEmpty ? currentSentence : (currentSentence.isEmpty ? activeWord : "\(currentSentence) \(activeWord)")
                if !fullDisplayed.isEmpty {
                    TypingBuffer.shared.recordForUndo(fullDisplayed)
                    let bsCount = fullDisplayed.count + (activeWord.isEmpty ? 1 : 0)
                    postBackspaces(bsCount)
                    postUnicodeString(item.text + " ")
                } else {
                    postUnicodeString(item.text + " ")
                }
            }
            clearMouseReset()
            engine.reset()
            TypingBuffer.shared.clear()
            for tok in item.text.components(separatedBy: .whitespaces) where !tok.isEmpty {
                TypingBuffer.shared.appendWord(tok)
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
            clearMouseReset()
            engine.reset()
            TypingBuffer.shared.replaceLastWord(with: item.text)
            notifyTypingState()
            return
        }

        // Case 3: Replace the word at the cursor (e.g. "duoc|" -> "được " or mid-word "du|oc" -> "được")
        if item.replaceCurrentWord && !activeWord.isEmpty {
            let leftCount = (ctx != nil && (!ctx!.wordPrefix.isEmpty || !ctx!.wordSuffix.isEmpty)) ? ctx!.wordPrefix.count : activeWord.count
            let rightCount = ctx?.wordSuffix.count ?? 0

            if leftCount > 0 {
                postBackspaces(leftCount)
            }
            if rightCount > 0 {
                postForwardDeletes(rightCount)
            }

            let hasSpaceAfterCursor: Bool = {
                if let ctx = ctx {
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
            clearMouseReset()
            engine.reset()
            for tok in item.text.components(separatedBy: .whitespaces) where !tok.isEmpty {
                TypingBuffer.shared.appendWord(tok)
            }
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
        for _ in 0..<count {
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
            }
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
