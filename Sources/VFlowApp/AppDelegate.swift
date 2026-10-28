import AppKit
import SwiftUI
import os
import VFlowCore
import VFlowPlatform
import VFlowUI

private let logger = Logger(subsystem: "com.apexdev.vflow", category: "AppDelegate")

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tapMonitorTimer: Timer?
    private var backgroundActivity: NSObjectProtocol?
    private var lastCaretRect: CGRect = CGRect(x: 600, y: 800, width: 200, height: 36)

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--speech-worker") {
            NSApp.setActivationPolicy(.accessory)
            VoiceDictationService.shared.startSpeechWorkerServiceMode()
            return
        }

        // Prevent macOS App Nap and Automatic Termination from throttling or killing the background CGEventTap
        ProcessInfo.processInfo.disableAutomaticTermination("VFlow Input Daemon")
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "VFlow Real-Time System Keyboard EventTap"
        )

        // 1. Check & prompt for accessibility permission if not already trusted
        let trusted = AccessibilityBridge.shared.isAccessibilityGranted(prompt: true)
        EventTapHook.shared.logDiagnostic("LAUNCH trusted=\(trusted) args=\(CommandLine.arguments)")
        if !trusted {
            logger.info("Accessibility permission not yet granted. Prompting user...")
        }

        // 2. Wire Live Caret Pill HUD & Smart Suggestion callbacks + Prewarm Apple On-Device Neural Engine LLM
        setupLiveCaretHUD()
        Task {
            await OnDeviceAIEngine.shared.prewarm()
        }

        // 3. Start keyboard event tap hook immediately (and keep monitoring every 1.5s in case permission is granted while running)
        let tapSuccess = EventTapHook.shared.start()
        if tapSuccess {
            logger.info("Keyboard EventTap successfully started.")
        } else {
            logger.info("EventTap waiting for Accessibility/Input Monitoring permission...")
        }

        tapMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            if !EventTapHook.shared.isTapActive {
                if EventTapHook.shared.start() {
                    logger.info("Keyboard EventTap auto-activated!")
                }
            }
        }

        // 4. Initialize Centralized Control Center Store & Setup Menu Bar Status Item
        _ = VFlowControlCenterStore.shared
        MenuBarCoordinator.shared.setup()
        EventTapHook.shared.onInputMethodChanged = { [weak self] newMethod in
            Task { @MainActor in
                VFlowControlCenterStore.shared.syncInputMethodFromExternal(newMethod)
                self?.presentCaretHUDAtFocusedElement(
                    composingWord: "",
                    rawWord: "",
                    sentenceWords: []
                )
            }
        }
        MenuBarCoordinator.shared.onOpenSettings = {
            BentoSettingsWindowController.shared.showWindow()
        }
        MenuBarCoordinator.shared.onToggleHUDPreview = {
            self.toggleCaretPillHUD()
        }
        MenuBarCoordinator.shared.onQuit = {
            NSApp.terminate(nil)
        }

        // 5. Setup Push-to-Talk & Real-Time Voice-to-Text Pipeline
        setupVoiceDictationPipeline()
        VoiceDictationService.shared.prewarmSpeechWorkerIfNeeded()
        PushToTalkMonitor.shared.start()

        // 6. Set activationPolicy to accessory (Menu Bar + Floating Window) & load 3D Liquid Glass App Icon
        NSApp.setActivationPolicy(.accessory)
        let rawIconPaths: [String?] = [
            Bundle.main.url(forResource: "app_icon_nobg", withExtension: "png")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("app_icon_nobg.png").path,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/app_icon_nobg.png").path
        ]
        let iconPaths = rawIconPaths.compactMap { $0 }
        if let iconPath = iconPaths.first(where: { FileManager.default.fileExists(atPath: $0) }),
           let appIcon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = appIcon
        }
        if !CommandLine.arguments.contains("--daemon") || CommandLine.arguments.contains("--show-settings") {
            BentoSettingsWindowController.shared.showWindow()
        }

        // Show initial Live Caret Pill HUD at the active text box right away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.presentCaretHUDAtFocusedElement(
                composingWord: "",
                rawWord: "",
                sentenceWords: []
            )
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        tapMonitorTimer?.invalidate()
        EventTapHook.shared.stop()
        PushToTalkMonitor.shared.stop()
        VoiceDictationService.shared.terminateSpeechWorker()
    }

    private func setupLiveCaretHUD() {
        CaretHUDModel.shared.onSelectSuggestion = { [weak self] item in
            let frame = self?.currentCaretPillFrame()
            CaretHUDModel.shared.isApplyingSuggestion = true
            EventTapHook.shared.applySuggestion(item)
            CaretHUDModel.shared.triggerSuggestionAcceptFeedback(for: item, caretFrame: frame) {
                EventTapHook.shared.notifyTypingState()
            }
        }
        CaretHUDModel.shared.onToggleInputMethod = {
            let current = EventTapHook.shared.engine.inputMethod
            let next: InputMethod = (current == .off) ? .telex : .off
            VFlowControlCenterStore.shared.inputMethod = next
        }
        CaretHUDModel.shared.onCycleTone = { [weak self] in
            let allTones = PolishTone.allCases
            let current = VFlowControlCenterStore.shared.currentTone
            if let idx = allTones.firstIndex(of: current) {
                let nextTone = allTones[(idx + 1) % allTones.count]
                VFlowControlCenterStore.shared.currentTone = nextTone
                EventTapHook.shared.notifyTypingState()
                _ = self
            }
        }
        CaretHUDModel.shared.onUndo = {
            EventTapHook.shared.postSyntheticKey(KeyCodeMap.kVK_ANSI_Z, flags: .maskCommand)
        }

        EventTapHook.shared.onHUDMouseDown = { screenPoint in
            MainActor.assumeIsolated {
                CaretPillWindow.shared.handleMouseDown(atScreenPoint: screenPoint)
            }
        }

        EventTapHook.shared.hasActiveSuggestions = {
            MainActor.assumeIsolated {
                CaretPillWindow.shared.isVisible && !CaretHUDModel.shared.visibleSuggestions.isEmpty
            }
        }

        EventTapHook.shared.onDoubleTabArmedChanged = { isArmed in
            Task { @MainActor in
                CaretHUDModel.shared.isDoubleTabArmed = isArmed
            }
        }

        EventTapHook.shared.onTypingStateChanged = { [weak self] composingWord, rawWord, sentenceWords, method, fullSentenceText, wordAfterCursor in
            Task { @MainActor in
                CaretHUDModel.shared.inputMethod = method
                self?.presentCaretHUDAtFocusedElement(
                    composingWord: composingWord,
                    rawWord: rawWord,
                    sentenceWords: sentenceWords,
                    fullSentenceText: fullSentenceText,
                    wordAfterCursor: wordAfterCursor
                )
            }
        }

        EventTapHook.shared.onSelectSuggestionShortcut = { [weak self] index in
            MainActor.assumeIsolated {
                let suggestions = CaretHUDModel.shared.visibleSuggestions
                guard index >= 0 && index < suggestions.count else { return false }
                let chosen = suggestions[index]
                let frame = self?.currentCaretPillFrame()
                CaretHUDModel.shared.isApplyingSuggestion = true
                EventTapHook.shared.applySuggestion(chosen)
                CaretHUDModel.shared.triggerSuggestionAcceptFeedback(for: chosen, caretFrame: frame) {
                    EventTapHook.shared.notifyTypingState()
                }
                return true
            }
        }

        EventTapHook.shared.onDismissHUD = {
            Task { @MainActor in
                CaretHUDModel.shared.hideHUD()
            }
        }
    }

    private func setupVoiceDictationPipeline() {
        PushToTalkMonitor.shared.onStartRecording = {
            Task { @MainActor in
                VoiceDictationService.shared.startRecording()
            }
        }
        PushToTalkMonitor.shared.onStopRecording = {
            Task { @MainActor in
                VoiceDictationService.shared.stopRecording()
            }
        }

        VoiceDictationService.shared.onRecordingStateChanged = { [weak self] isRecording, status in
            Task { @MainActor in
                guard let self = self else { return }
                PushToTalkMonitor.shared.syncRecordingState(isRecording)
                VFlowControlCenterStore.shared.updateVoiceRecordingState(isRecording: isRecording, status: status)
                if isRecording {
                    let langBadge = VoiceDictationService.shared.currentLocaleIdentifier.hasPrefix("en") ? "EN" : "VI"
                    CaretHUDModel.shared.presentVoiceRecording(
                        displayText: "🎙 Đang nghe (\(langBadge))... Nói vào Micro (⌥Space để dừng)",
                        audioLevel: 0.25,
                        caretFrame: self.currentCaretPillFrame()
                    )
                } else if VoiceDictationService.shared.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CaretHUDModel.shared.hideHUD()
                }
            }
        }

        VoiceDictationService.shared.onPartialTranscript = { [weak self] partialText, level in
            Task { @MainActor in
                guard let self = self else { return }
                VFlowControlCenterStore.shared.updateVoicePartial(text: partialText, audioLevel: level)
                let langBadge = VoiceDictationService.shared.currentLocaleIdentifier.hasPrefix("en") ? "EN" : "VI"
                let trimmed = partialText.trimmingCharacters(in: .whitespacesAndNewlines)
                let display = trimmed.isEmpty
                    ? "🎙 Đang nghe (\(langBadge))... Nói vào Micro (⌥Space để dừng)"
                    : "🎙 \(trimmed)"
                CaretHUDModel.shared.presentVoiceRecording(
                    displayText: display,
                    audioLevel: level,
                    caretFrame: self.currentCaretPillFrame()
                )
            }
        }

        VoiceDictationService.shared.onFinalTranscript = { [weak self] finalText in
            Task { @MainActor in
                guard let self = self else { return }
                let trimmedRaw = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedRaw.isEmpty else {
                    CaretHUDModel.shared.hideHUD()
                    return
                }
                let tone = VFlowControlCenterStore.shared.currentTone
                let polished = VietnameseTextPolisher.polish(trimmedRaw, tone: tone)
                VFlowControlCenterStore.shared.updateVoiceFinal(raw: trimmedRaw, polished: polished)

                let frame = self.currentCaretPillFrame()
                // Inject directly into active text field if the user is not inside the VFlow Settings window
                let isSettingsKeyWindow = (BentoSettingsWindowController.shared.window?.isKeyWindow == true)
                var insertedCount = 0
                if !isSettingsKeyWindow {
                    insertedCount = EventTapHook.shared.injectVoiceTranscript(polished)
                }

                let undoLen = insertedCount
                CaretHUDModel.shared.onUndo = {
                    if undoLen > 0 {
                        EventTapHook.shared.postBackspaces(undoLen)
                    }
                    CaretHUDModel.shared.hideHUD()
                }
                CaretHUDModel.shared.presentVoiceCompleted(
                    polishedText: polished,
                    caretFrame: frame
                )
            }
        }
    }

    private func currentCaretPillFrame() -> CGRect {
        if let liveRect = CaretLocator.shared.findCaretScreenRect() {
            lastCaretRect = liveRect
        }
        let caretPoint = CGPoint(x: lastCaretRect.midX, y: lastCaretRect.midY)
        let targetScreen = NSScreen.screens.first { screen in
            NSPointInRect(caretPoint, screen.frame)
        } ?? NSScreen.main ?? NSScreen.screens.first
        let screen = targetScreen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CaretLocator.calculatePillFrame(
            caretRect: lastCaretRect,
            pillSize: CGSize(width: 460, height: 52),
            screenFrame: screen
        )
    }

    private func presentCaretHUDAtFocusedElement(
        composingWord: String,
        rawWord: String,
        sentenceWords: [String],
        fullSentenceText: String = "",
        wordAfterCursor: String = ""
    ) {
        let pillFrame = currentCaretPillFrame()

        CaretHUDModel.shared.updateOnTyping(
            currentWord: composingWord,
            rawWord: rawWord,
            sentenceWords: sentenceWords,
            inputMethod: EventTapHook.shared.engine.inputMethod,
            caretFrame: pillFrame,
            fullSentenceText: fullSentenceText,
            wordAfterCursor: wordAfterCursor
        )
    }

    private func toggleCaretPillHUD() {
        presentCaretHUDAtFocusedElement(
            composingWord: "tiếng",
            rawWord: "tieengs",
            sentenceWords: ["gõ", "tiếng"]
        )
    }
}
