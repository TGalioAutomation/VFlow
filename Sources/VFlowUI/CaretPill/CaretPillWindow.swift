import Foundation
import AppKit
import SwiftUI
import VFlowCore

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
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override public var canBecomeKey: Bool {
        false
    }

    override public var canBecomeMain: Bool {
        false
    }

    /// Positions and presents the Caret Pill HUD at the specified frame without activating the application,
    /// dynamically sizing width to fit all suggestion text without truncation, clamped to the target screen.
    public func present(at frame: CGRect) {
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
        self.orderFrontRegardless()
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
    @Published public var suggestions: [SuggestionItem] = []
    @Published public var audioLevel: Float = 0.35
    @Published public var currentTone: PolishTone = .natural
    @Published public var inputMethod: InputMethod = .telex
    @Published public var severity: SuggestionSeverity = .normal

    public var onSelectSuggestion: ((SuggestionItem) -> Void)?
    public var onToggleInputMethod: (() -> Void)?
    public var onUndo: (() -> Void)?
    public var onCycleTone: (() -> Void)?

    private var autoHideTimer: Timer?
    private var decayTimer: Timer?
    private var aiInferenceTask: Task<Void, Never>?
    private var isHosted = false

    public init() {}

    /// Ensures CaretPillWindow has its NSHostingView bound to CaretHUDModel.shared.
    public func ensureHosted() {
        if !isHosted || !(CaretPillWindow.shared.contentView is NSHostingView<CaretHUDContainerView>) {
            restoreHosting()
        }
    }

    /// Restores CaretPillWindow's hosting view back to CaretHUDContainerView.
    public func restoreHosting() {
        isHosted = true
        let root = CaretHUDContainerView(model: self)
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(x: 0, y: 0, width: 460, height: 52)
        CaretPillWindow.shared.contentView = hostingView
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
        self.currentWord = currentWord
        self.inputMethod = inputMethod
        self.state = .transcript

        let fullSentence = !fullSentenceText.isEmpty
            ? fullSentenceText
            : (sentenceWords + (currentWord.isEmpty ? [] : [currentWord])).joined(separator: " ")
        self.text = fullSentence

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

        // Pulse the 120fps Silk Sine-Wave
        self.audioLevel = min(1.0, self.audioLevel + 0.35)
        scheduleWaveDecay()

        CaretPillWindow.shared.present(at: caretFrame)
        resetAutoHideTimer(seconds: 6.0)

        // Stage 2: Asynchronous debounced Apple On-Device FoundationModels Neural Engine LLM inference
        aiInferenceTask?.cancel()
        let wordCount = fullSentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
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
            if capturedCurrentWord.isEmpty,
               !aiResult.nextWord.isEmpty,
               !updated.contains(where: { $0.text.lowercased() == aiResult.nextWord.lowercased() }) {
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
                self.resetAutoHideTimer(seconds: 7.0)
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
        resetAutoHideTimer(seconds: 15.0)
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
            onUndo: { model.onUndo?() },
            onCycleTone: { model.onCycleTone?() },
            onSelectSuggestion: { item in model.onSelectSuggestion?(item) },
            onToggleInputMethod: { model.onToggleInputMethod?() }
        )
    }
}
