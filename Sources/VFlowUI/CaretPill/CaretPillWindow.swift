import Foundation
import AppKit
import SwiftUI
import VFlowCore

/// Non-activating NSHostingView that accepts first-mouse events without requiring window activation or dragging.
public final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override public var mouseDownCanMoveWindow: Bool {
        return false
    }
}

/// Non-activating floating NSPanel for displaying the Caret Pill HUD without stealing focus.
public final class CaretPillWindow: NSPanel, @unchecked Sendable {
    public static let shared = CaretPillWindow()

    public init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 460, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.becomesKeyOnlyIfNeeded = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override public var canBecomeKey: Bool {
        false
    }

    override public var canBecomeMain: Bool {
        false
    }

    /// Handles a global mouse-down at the specified screen coordinate (AppKit bottom-left screen space).
    /// Returns `true` if the click landed inside the visible Caret Pill HUD so `EventTapHook` can swallow it without stealing focus from the active text input.
    @MainActor
    public func handleMouseDown(atScreenPoint screenPoint: CGPoint) -> Bool {
        guard self.isVisible else { return false }
        let winFrame = self.frame
        guard winFrame.insetBy(dx: -4, dy: -4).contains(screenPoint) else { return false }

        let localX = screenPoint.x - winFrame.minX
        let localY = winFrame.maxY - screenPoint.y
        let localPoint = CGPoint(x: localX, y: localY)
        return CaretHUDModel.shared.dispatchHitTest(at: localPoint, windowSize: winFrame.size)
    }

    private func applyFittingFrame(for frame: CGRect) {
        self.contentView?.invalidateIntrinsicContentSize()
        self.contentView?.layoutSubtreeIfNeeded()
        let fitting = self.contentView?.fittingSize ?? frame.size

        let anchorPoint = CGPoint(x: frame.midX, y: frame.midY)
        let targetScreen = NSScreen.screens.first { screen in
            NSPointInRect(anchorPoint, screen.frame)
        } ?? NSScreen.main ?? NSScreen.screens.first
        let screen = targetScreen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let dynamicWidth = min(screen.width - 24, max(380, ceil(fitting.width)))
        let dynamicHeight = max(52, ceil(fitting.height))

        var adjustedOriginX = anchorPoint.x - (dynamicWidth / 2.0)
        if adjustedOriginX + dynamicWidth > screen.maxX - 12 {
            adjustedOriginX = max(screen.minX + 12, screen.maxX - dynamicWidth - 12)
        }
        if adjustedOriginX < screen.minX + 12 {
            adjustedOriginX = screen.minX + 12
        }

        var adjustedOriginY = frame.origin.y
        if adjustedOriginY + dynamicHeight > screen.maxY - 4 {
            adjustedOriginY = screen.maxY - dynamicHeight - 4
        }
        if adjustedOriginY < screen.minY + 8 {
            adjustedOriginY = screen.minY + 8
        }

        let finalFrame = CGRect(
            x: adjustedOriginX,
            y: adjustedOriginY,
            width: dynamicWidth,
            height: dynamicHeight
        )
        self.setFrame(finalFrame, display: true, animate: false)
    }

    /// Positions and presents the Caret Pill HUD at the specified frame without activating the application,
    /// dynamically sizing width and height (including 2-Tier Card layout) to fit all suggestion text without truncation.
    public func present(at frame: CGRect) {
        applyFittingFrame(for: frame)
        self.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isVisible else { return }
            self.applyFittingFrame(for: frame)
        }
    }

    /// Smoothly hides the Caret Pill HUD.
    public func dismiss() {
        self.orderOut(nil)
    }
}

/// Reactive state container & coordinator for the real-time Caret Pill HUD & Suggestion Bar.
@MainActor
public final class CaretHUDModel: ObservableObject {
    public static let shared = CaretHUDModel()

    @Published public var state: CaretPillState = .transcript
    @Published public var text: String = ""
    @Published public var currentWord: String = ""
    @Published public var suggestions: [SuggestionItem] = [] {
        didSet {
            chipFrames.removeAll()
        }
    }
    @Published public var audioLevel: Float = 0.35
    @Published public var currentTone: PolishTone = .natural
    @Published public var inputMethod: InputMethod = .telex
    @Published public var severity: SuggestionSeverity = .normal
    @Published public var acceptShortcut: SuggestionAcceptShortcut = .doubleTab
    @Published public var isDoubleTabArmed: Bool = false
    @Published public var isApplyingSuggestion: Bool = false
    @Published public var isSuggestionAppliedSuccess: Bool = false
    @Published public var appliedSuggestionText: String = ""

    public var chipFrames: [Int: CGRect] = [:]
    public var modeButtonFrame: CGRect = .zero
    public var undoButtonFrame: CGRect = .zero
    public var toneButtonFrame: CGRect = .zero

    public var onSelectSuggestion: ((SuggestionItem) -> Void)?
    public var onToggleInputMethod: (() -> Void)?
    public var onUndo: (() -> Void)?
    public var onCycleTone: (() -> Void)?
    public var onStopVoiceRecording: (() -> Void)?

    private var autoHideTimer: Timer?
    private var decayTimer: Timer?
    private var aiInferenceTask: Task<Void, Never>?
    private var suggestionFeedbackTask: Task<Void, Never>?
    private var lastCaretFrame: CGRect = CGRect(x: 400, y: 400, width: 460, height: 52)
    private var isHosted = false

    public init() {}

    public var visibleSuggestions: [SuggestionItem] {
        guard !suggestions.isEmpty else { return [] }
        if let first = suggestions.first, first.kind == .aiPolish, first.text.count > 26 {
            return [first]
        }
        let hasLongPolish = suggestions.prefix(2).contains { $0.kind == .aiPolish && $0.text.count > 12 }
        if hasLongPolish {
            return Array(suggestions.prefix(2))
        }
        return Array(suggestions.prefix(3))
    }

    /// Ensures CaretPillWindow has its FirstMouseHostingView bound to CaretHUDModel.shared.
    public func ensureHosted() {
        if !isHosted || !(CaretPillWindow.shared.contentView is FirstMouseHostingView<CaretHUDContainerView>) {
            restoreHosting()
        }
    }

    /// Restores CaretPillWindow's hosting view back to CaretHUDContainerView.
    public func restoreHosting() {
        isHosted = true
        let root = CaretHUDContainerView(model: self)
        let hostingView = FirstMouseHostingView(rootView: root)
        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.frame = NSRect(x: 0, y: 0, width: 460, height: 52)
        CaretPillWindow.shared.contentView = hostingView
    }

    /// Hit-tests a click inside the Caret Pill HUD in local top-left coordinates and invokes the matching action without stealing focus.
    public func dispatchHitTest(at localPoint: CGPoint, windowSize: CGSize) -> Bool {
        let visible = visibleSuggestions
        let isTopBarRow = localPoint.y <= 46

        // 0. Check top-bar utility controls (VI/EN Mode toggle, Undo, and Cycle Tone)
        if isTopBarRow {
            if modeButtonFrame.width > 0,
               modeButtonFrame.insetBy(dx: -5, dy: -6).contains(localPoint) {
                DispatchQueue.main.async { [weak self] in
                    self?.onToggleInputMethod?()
                }
                return true
            }
            if undoButtonFrame.width > 0,
               undoButtonFrame.insetBy(dx: -5, dy: -6).contains(localPoint) {
                DispatchQueue.main.async { [weak self] in
                    self?.onUndo?()
                }
                return true
            }
            if toneButtonFrame.width > 0,
               toneButtonFrame.insetBy(dx: -5, dy: -6).contains(localPoint) {
                DispatchQueue.main.async { [weak self] in
                    self?.onCycleTone?()
                }
                return true
            }
            // Fallback top-bar regions if GeometryReader frames have not yet populated
            if modeButtonFrame.width == 0 && localPoint.x >= 60 && localPoint.x <= 108 {
                DispatchQueue.main.async { [weak self] in
                    self?.onToggleInputMethod?()
                }
                return true
            }
            if undoButtonFrame.width == 0 && localPoint.x >= windowSize.width - 115 && localPoint.x < windowSize.width - 72 {
                DispatchQueue.main.async { [weak self] in
                    self?.onUndo?()
                }
                return true
            }
            if toneButtonFrame.width == 0 && localPoint.x >= windowSize.width - 72 {
                DispatchQueue.main.async { [weak self] in
                    self?.onCycleTone?()
                }
                return true
            }
        }

        // 1. When there is a single visible suggestion (including 2-Tier Long Card or 1-line full-sentence .aiPolish),
        // any click outside the top-bar utility controls selects that suggestion immediately.
        if visible.count == 1, let first = visible.first {
            DispatchQueue.main.async { [weak self] in
                self?.onSelectSuggestion?(first)
            }
            return true
        }

        // 2. Check recorded suggestion chip frames (multi-chip horizontal pill mode)
        for idx in 0..<visible.count {
            if let rect = chipFrames[idx],
               rect.width > 0,
               localPoint.x >= rect.minX - 6 && localPoint.x <= rect.maxX + 6 {
                let chosen = visible[idx]
                DispatchQueue.main.async { [weak self] in
                    self?.onSelectSuggestion?(chosen)
                }
                return true
            }
        }

        // 3. Nearest-chip & proportional horizontal fallback so clicking anywhere in the suggestion zone always selects a chip
        if !visible.isEmpty {
            var bestIdx: Int?
            var bestDist = CGFloat.greatestFiniteMagnitude
            for idx in 0..<visible.count {
                if let rect = chipFrames[idx], rect.width > 0 {
                    let dist = abs(localPoint.x - rect.midX)
                    if dist < bestDist {
                        bestDist = dist
                        bestIdx = idx
                    }
                }
            }
            if let matched = bestIdx {
                let chosen = visible[matched]
                DispatchQueue.main.async { [weak self] in
                    self?.onSelectSuggestion?(chosen)
                }
                return true
            }

            let chipRegionStart: CGFloat = 108
            let chipRegionEnd: CGFloat = max(chipRegionStart + 40, windowSize.width - 115)
            let weights = visible.map { CGFloat(max(6, $0.text.count + 5)) }
            let totalWeight = max(1, weights.reduce(0, +))
            let ratio = max(0, min(0.999, (localPoint.x - chipRegionStart) / (chipRegionEnd - chipRegionStart)))
            var accum: CGFloat = 0
            var matchedIndex = visible.count - 1
            for (idx, w) in weights.enumerated() {
                accum += w / totalWeight
                if ratio <= accum {
                    matchedIndex = idx
                    break
                }
            }
            let chosen = visible[matchedIndex]
            DispatchQueue.main.async { [weak self] in
                self?.onSelectSuggestion?(chosen)
            }
            return true
        }

        // 4. If currently recording voice (state == .working), clicking the Caret Pill HUD immediately stops & injects
        if state == .working {
            DispatchQueue.main.async { [weak self] in
                self?.onStopVoiceRecording?()
            }
            return true
        }

        return true
    }

    /// Triggers a 2-stage visual animation (`✨ Đang sửa văn bản...` -> `✓ Đã sửa văn bản`) when a suggestion is accepted via `⇥⇥`, `⌥1..3`, or mouse click.
    public func triggerSuggestionAcceptFeedback(
        for item: SuggestionItem,
        caretFrame: CGRect? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        ensureHosted()
        aiInferenceTask?.cancel()
        suggestionFeedbackTask?.cancel()
        decayTimer?.invalidate()

        let frame = caretFrame ?? lastCaretFrame
        lastCaretFrame = frame

        let preview = item.text.replacingOccurrences(of: "\n", with: " ↵ ")
        self.isDoubleTabArmed = false
        self.isApplyingSuggestion = true
        self.isSuggestionAppliedSuccess = false
        self.appliedSuggestionText = preview
        self.state = .working
        self.audioLevel = 1.0
        self.suggestions = []

        CaretPillWindow.shared.present(at: frame)
        resetAutoHideTimer(seconds: 6.0)

        suggestionFeedbackTask = Task { @MainActor [weak self] in
            // Stage 1: 280ms Violet-Cyan AI Rewrite Pulse ("✨ Đang sửa văn bản...")
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled, let self = self else { return }

            // Stage 2: 1100ms Emerald Checkmark Confirmation ("✓ Đã sửa văn bản")
            self.isApplyingSuggestion = false
            self.isSuggestionAppliedSuccess = true
            self.state = .done
            self.audioLevel = 0.45
            CaretPillWindow.shared.present(at: self.lastCaretFrame)

            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }

            self.isSuggestionAppliedSuccess = false
            self.appliedSuggestionText = ""
            self.state = .transcript
            onFinished?()
        }
    }

    /// Triggers a visual wave pulse and refreshes suggestions when a keystroke occurs.
    public func updateOnTyping(
        currentWord: String,
        rawWord: String,
        sentenceWords: [String],
        inputMethod: InputMethod,
        caretFrame: CGRect,
        fullSentenceText: String = "",
        wordAfterCursor: String = ""
    ) {
        ensureHosted()
        self.lastCaretFrame = caretFrame
        self.currentWord = currentWord
        self.inputMethod = inputMethod

        let fullSentence = !fullSentenceText.isEmpty
            ? fullSentenceText
            : (sentenceWords + (currentWord.isEmpty ? [] : [currentWord])).joined(separator: " ")
        self.text = fullSentence

        // While Stage 1 ("✨ Đang sửa văn bản...") is actively animating right after applySuggestion,
        // keep the visual rewrite feedback on screen instead of immediately overwriting it.
        if self.isApplyingSuggestion {
            return
        }

        // If the user types a new character while Stage 2 ("✓ Đã sửa văn bản") is showing, cancel it and return to live suggestions.
        if self.isSuggestionAppliedSuccess {
            suggestionFeedbackTask?.cancel()
            self.isSuggestionAppliedSuccess = false
            self.appliedSuggestionText = ""
        }

        self.state = .transcript

        var immediateSuggestions = SuggestionEngine.suggest(
            currentWord: currentWord,
            rawWord: rawWord,
            sentenceWords: sentenceWords,
            tone: currentTone,
            fullSentenceText: fullSentence,
            wordAfterCursor: wordAfterCursor,
            promoteAIPolishOnHighSeverity: true
        )
        let currentSeverity = SuggestionEngine.evaluateSeverity(
            rawSentence: fullSentence,
            tone: currentTone
        )
        self.severity = currentSeverity

        // Stage 1b: Synchronous <1ms Apple NSSpellChecker on-device neural completion for partial words
        if !currentWord.isEmpty && immediateSuggestions.count < 3 {
            let spellCompletions = OnDeviceAIEngine.spellCheckerCompletions(
                partialWord: currentWord,
                fullSentence: fullSentence,
                limit: 3
            )
            for comp in spellCompletions where immediateSuggestions.count < 3 {
                let lowerComp = comp.lowercased()
                if !immediateSuggestions.contains(where: { $0.text.lowercased() == lowerComp }) {
                    immediateSuggestions.append(
                        SuggestionItem(
                            text: comp,
                            kind: .wordCompletion,
                            replaceCurrentWord: true,
                            targetWordToReplace: currentWord
                        )
                    )
                }
            }
        }

        self.suggestions = immediateSuggestions

        // Never show a blank "Đang gõ văn bản..." pill when both the text and suggestions are empty
        if fullSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           currentWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           immediateSuggestions.isEmpty {
            hideHUD()
            return
        }

        // Pulse the 120fps Silk Sine-Wave
        self.audioLevel = min(1.0, self.audioLevel + 0.35)
        scheduleWaveDecay()

        CaretPillWindow.shared.present(at: caretFrame)
        resetAutoHideTimer(seconds: fullSentence.count > 56 ? 18.0 : 10.0)

        // Stage 2: Asynchronous debounced Apple On-Device FoundationModels Neural Engine LLM inference
        aiInferenceTask?.cancel()
        let wordCount = fullSentence.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        guard OnDeviceAIEngine.isFoundationModelAvailable, OnDeviceAIEngine.isNeuralPolishEnabled, wordCount >= 2 else { return }

        let capturedTone = self.currentTone
        let capturedSentence = fullSentence
        let capturedCurrentWord = currentWord
        let capturedFrame = caretFrame

        aiInferenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000) // 220ms debounce
            guard !Task.isCancelled, let self = self, self.text == capturedSentence else { return }

            guard let aiResult = await OnDeviceAIEngine.shared.inferSentencePolishAndNextWord(
                rawSentence: capturedSentence,
                tone: capturedTone
            ) else { return }

            guard !Task.isCancelled, self.text == capturedSentence else { return }

            var updated = self.suggestions
            let normalizedInput = VietnameseTextPolisher.normalizePunctuation(capturedSentence)

            // Merge Neural Engine ✨ Full-Sentence Polish if it improves/restores diacritics on the sentence
            let mergedSeverity = max(self.severity, aiResult.severity)
            self.severity = mergedSeverity

            if !aiResult.polishedSentence.isEmpty,
               aiResult.polishedSentence.lowercased() != normalizedInput.lowercased() {
                let aiPolishItem = SuggestionItem(
                    text: aiResult.polishedSentence,
                    kind: .aiPolish,
                    replaceCurrentWord: false,
                    severity: max(.moderate, mergedSeverity)
                )
                if let existingIdx = updated.firstIndex(where: { $0.kind == .aiPolish }) {
                    updated[existingIdx] = aiPolishItem
                } else if mergedSeverity == .high {
                    updated.insert(aiPolishItem, at: 0)
                    if updated.count > 3 { updated = Array(updated.prefix(3)) }
                } else if updated.count >= 2 {
                    updated.insert(aiPolishItem, at: 1)
                    if updated.count > 3 { updated = Array(updated.prefix(3)) }
                } else {
                    updated.append(aiPolishItem)
                }
                updated = SuggestionEngine.prioritizeForSeverity(updated, severity: mergedSeverity)
            }

            // Merge Neural Engine next-word prediction when cursor is after a completed word
            let cleanCapturedLower = capturedSentence
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()
            let cleanNextLower = aiResult.nextWord
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()
            let isDuplicateSuffix = !cleanNextLower.isEmpty &&
                (cleanCapturedLower == cleanNextLower || cleanCapturedLower.hasSuffix(" " + cleanNextLower))

            if capturedCurrentWord.isEmpty,
               !cleanNextLower.isEmpty,
               !isDuplicateSuffix,
               !updated.contains(where: { $0.text.lowercased() == cleanNextLower }) {
                let nextItem = SuggestionItem(
                    text: aiResult.nextWord,
                    kind: .nextWord,
                    replaceCurrentWord: false
                )
                if updated.count < 3 {
                    updated.append(nextItem)
                } else {
                    updated[updated.count - 1] = nextItem
                }
            }

            if updated != self.suggestions {
                self.suggestions = updated
                CaretPillWindow.shared.present(at: capturedFrame)
                self.resetAutoHideTimer(seconds: capturedSentence.count > 56 ? 18.0 : 12.0)
            }
        }
    }

    /// Presents the Caret Pill HUD in live Voice Recording mode with real-time RMS waveform and partial speech transcript.
    public func presentVoiceRecording(
        displayText: String,
        audioLevel: Float,
        caretFrame: CGRect
    ) {
        ensureHosted()
        aiInferenceTask?.cancel()
        decayTimer?.invalidate()
        self.suggestions = []
        self.currentWord = ""
        self.state = .working
        self.text = displayText
        self.audioLevel = max(0.25, min(1.0, audioLevel))
        CaretPillWindow.shared.present(at: caretFrame)
        resetAutoHideTimer(seconds: 60.0)
    }

    /// Presents the finalized & polished Voice Dictation result on the Caret Pill HUD.
    public func presentVoiceCompleted(
        polishedText: String,
        caretFrame: CGRect
    ) {
        ensureHosted()
        aiInferenceTask?.cancel()
        self.suggestions = []
        self.currentWord = ""
        self.state = .done
        self.text = polishedText
        self.audioLevel = 0.25
        CaretPillWindow.shared.present(at: caretFrame)
        resetAutoHideTimer(seconds: 5.0)
    }

    public func hideHUD() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        CaretPillWindow.shared.dismiss()
    }

    private func scheduleWaveDecay() {
        decayTimer?.invalidate()
        decayTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.audioLevel > 0.25 {
                    self.audioLevel = max(0.22, self.audioLevel - 0.12)
                } else {
                    self.decayTimer?.invalidate()
                    self.decayTimer = nil
                }
            }
        }
    }

    private func resetAutoHideTimer(seconds: TimeInterval) {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideHUD()
            }
        }
    }
}

/// Reactive wrapper view binding CaretHUDModel to CaretPillView.
public struct CaretHUDContainerView: View {
    @ObservedObject public var model: CaretHUDModel

    public init(model: CaretHUDModel) {
        self.model = model
    }

    public var body: some View {
        CaretPillView(
            state: $model.state,
            text: $model.text,
            audioLevel: $model.audioLevel,
            currentTone: $model.currentTone,
            currentWord: model.currentWord,
            suggestions: model.suggestions,
            inputMethod: model.inputMethod,
            severity: model.severity,
            acceptShortcut: model.acceptShortcut,
            isDoubleTabArmed: model.isDoubleTabArmed,
            isApplyingSuggestion: model.isApplyingSuggestion,
            isSuggestionAppliedSuccess: model.isSuggestionAppliedSuccess,
            appliedSuggestionText: model.appliedSuggestionText,
            onUndo: { model.onUndo?() },
            onCycleTone: { model.onCycleTone?() },
            onSelectSuggestion: { item in model.onSelectSuggestion?(item) },
            onToggleInputMethod: { model.onToggleInputMethod?() },
            onUpdateChipFrame: { idx, rect in model.chipFrames[idx] = rect },
            onUpdateModeButtonFrame: { rect in model.modeButtonFrame = rect },
            onUpdateUndoButtonFrame: { rect in model.undoButtonFrame = rect },
            onUpdateToneButtonFrame: { rect in model.toneButtonFrame = rect }
        )
    }
}
