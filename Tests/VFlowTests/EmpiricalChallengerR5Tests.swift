import XCTest
import AppKit
import SwiftUI
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

/// Adversarial empirical verification test suite authored and executed by Challenger R5.2.
/// Stress-tests UI Lifecycle, Menu Shortcuts, HUD Interaction, and CPU Optimization:
/// 1. `SilkSineWaveView` pausable TimelineView & `CaretHUDModel.isWavePaused` dynamic state matrix.
/// 2. `VFlowControlCenterStore` telemetry polling lifecycle (startup, showWindow, windowWillClose).
/// 3. `CaretPillWindow.dispatchHitTest` click pass-through & `handleMouseDown` dismissal over Settings / Menu Bar.
final class EmpiricalChallengerR5Tests: XCTestCase {

    // MARK: - Scope 1: SilkSineWaveView Pausable TimelineView & CPU Optimization

    @MainActor
    func testSilkSineWaveView_PausableTimelineViewDirectState() {
        // Direct View struct construction
        let pausedWave = SilkSineWaveView(state: .transcript, audioLevel: 0.1, isPaused: true)
        XCTAssertTrue(pausedWave.isPaused, "Direct SilkSineWaveView must honor isPaused=true")

        let activeWave = SilkSineWaveView(state: .transcript, audioLevel: 0.8, isPaused: false)
        XCTAssertFalse(activeWave.isPaused, "Direct SilkSineWaveView must honor isPaused=false")
    }

    @MainActor
    func testSilkSineWaveView_PausableStateAdversarialMatrix() {
        let model = CaretHUDModel.shared

        // --- SUBTEST A: HUD Dismissed / Hidden ---
        // When HUD is dismissed (isHUDVisible == false), isWavePaused MUST BE true regardless of state and audioLevel.
        model.isHUDVisible = false

        let states: [CaretPillState] = [.transcript, .working, .done]
        let audioLevels: [Float] = [-1.0, 0.0, 0.15, 0.25, 0.26, 0.75, 1.0, 2.0]

        for st in states {
            for lvl in audioLevels {
                model.state = st
                model.audioLevel = lvl
                XCTAssertTrue(
                    model.isWavePaused,
                    "isWavePaused must be TRUE when HUD is dismissed (state=\(st), audioLevel=\(lvl))"
                )
            }
        }

        // --- SUBTEST B: HUD Visible in .transcript state ---
        model.isHUDVisible = true
        model.state = .transcript

        // Audio levels <= 0.25 must pause the wave (motionless / idle)
        let idleAudioLevels: [Float] = [0.0, 0.05, 0.10, 0.20, 0.249, 0.25]
        for lvl in idleAudioLevels {
            model.audioLevel = lvl
            XCTAssertTrue(
                model.isWavePaused,
                "isWavePaused must be TRUE when audioLevel <= 0.25 in .transcript (audioLevel=\(lvl))"
            )
        }

        // Audio levels > 0.25 must animate the wave (active)
        let activeAudioLevels: [Float] = [0.251, 0.30, 0.50, 0.75, 1.0]
        for lvl in activeAudioLevels {
            model.audioLevel = lvl
            XCTAssertFalse(
                model.isWavePaused,
                "isWavePaused must be FALSE when audioLevel > 0.25 in .transcript (audioLevel=\(lvl))"
            )
        }

        // --- SUBTEST C: HUD Visible in .working or .done state ---
        model.isHUDVisible = true
        model.state = .working
        model.audioLevel = 0.10 // Even with low audioLevel, working state represents active AI/voice processing
        XCTAssertFalse(model.isWavePaused, "isWavePaused must be FALSE when state is .working")

        model.state = .done
        model.audioLevel = 0.10
        XCTAssertFalse(model.isWavePaused, "isWavePaused must be FALSE when state is .done")

        // Cleanup
        model.isHUDVisible = false
    }

    @MainActor
    func testSilkSineWaveView_DynamicTransitionsOnTypingAndVoice() {
        let model = CaretHUDModel.shared
        model.isHUDVisible = false
        XCTAssertTrue(model.isWavePaused)

        // 1. Typing activity triggers updateOnTyping -> becomes visible and unpaused
        let testCaretFrame = CGRect(x: 400, y: 400, width: 460, height: 52)
        model.updateOnTyping(
            currentWord: "vflow",
            rawWord: "vflow",
            sentenceWords: ["test"],
            inputMethod: .telex,
            caretFrame: testCaretFrame
        )

        XCTAssertTrue(model.isHUDVisible, "Typing must present the Caret HUD")
        XCTAssertGreaterThan(model.audioLevel, 0.25, "Typing must boost audio level above idle threshold")
        XCTAssertFalse(model.isWavePaused, "Wave must NOT be paused when typing activity occurs")

        // 2. Hide HUD -> immediately paused
        model.hideHUD()
        XCTAssertFalse(model.isHUDVisible)
        XCTAssertTrue(model.isWavePaused, "Wave must be paused immediately when HUD is hidden")

        // 3. Voice recording active via presentVoiceRecording -> becomes visible and unpaused
        model.presentVoiceRecording(
            displayText: "🎙 Đang nghe...",
            audioLevel: 0.6,
            caretFrame: testCaretFrame
        )
        XCTAssertTrue(model.isHUDVisible, "Voice recording must present HUD")
        XCTAssertEqual(model.state, .working, "Voice recording state must be .working")
        XCTAssertFalse(model.isWavePaused, "Wave must NOT be paused during active voice recording")

        // Cleanup
        model.hideHUD()
    }

    // MARK: - Scope 2: VFlowControlCenterStore Telemetry Polling Lifecycle

    @MainActor
    func testVFlowControlCenterStore_TelemetryPollingLifecycleAndIdempotency() {
        let store = VFlowControlCenterStore.shared
        let controller = BentoSettingsWindowController.shared

        // 1. Invalidate any existing timer to test baseline
        store.stopTelemetryPolling()
        XCTAssertFalse(store.isTelemetryPollingActive, "Telemetry polling must be inactive on baseline/startup")

        // 2. Presenting settings window starts telemetry polling
        controller.showWindow()
        XCTAssertTrue(store.isTelemetryPollingActive, "Telemetry polling must be active when Bento settings window is shown")
        XCTAssertEqual(NSApp.activationPolicy(), .regular, "Activation policy must be .regular while settings window is open")

        // 3. Idempotent multiple showWindow calls must not duplicate or crash timer
        controller.showWindow()
        controller.showWindow()
        XCTAssertTrue(store.isTelemetryPollingActive, "Telemetry polling remains active on repeated showWindow calls")

        // 4. Closing settings window stops telemetry polling and reverts activation policy
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        XCTAssertFalse(store.isTelemetryPollingActive, "Telemetry polling must be stopped when Bento settings window closes")
        XCTAssertEqual(NSApp.activationPolicy(), .accessory, "Activation policy must revert to .accessory when closed")

        // 5. Explicit start/stop calls
        store.startTelemetryPolling()
        XCTAssertTrue(store.isTelemetryPollingActive)
        store.stopTelemetryPolling()
        XCTAssertFalse(store.isTelemetryPollingActive)
    }

    // MARK: - Scope 4: CaretPillWindow Floating Level & Hit-Test Guard

    @MainActor
    func testCaretPillWindow_FloatingLevelAndNonInteractiveClickPassThrough() {
        let win = CaretPillWindow.shared
        let model = CaretHUDModel.shared

        // 1. Verify window level is .floating (3), not .popUpMenu (101)
        XCTAssertEqual(win.level, .floating, "CaretPillWindow level must be .floating to prevent window layer collisions")
        XCTAssertTrue(win.isFloatingPanel)

        // 2. dispatchHitTest on non-interactive background areas must return false (pass through)
        model.suggestions = []
        model.state = .transcript

        let testWindowSize = CGSize(width: 460, height: 52)

        // Empty area near sine wave / logo (x: 20, y: 20)
        let hitPillBackground = model.dispatchHitTest(at: CGPoint(x: 20, y: 20), windowSize: testWindowSize)
        XCTAssertFalse(hitPillBackground, "Click outside interactive chips must return false (pass-through)")

        // Area below top bar when no suggestions exist (x: 200, y: 60)
        let hitEmptyBottom = model.dispatchHitTest(at: CGPoint(x: 200, y: 60), windowSize: testWindowSize)
        XCTAssertFalse(hitEmptyBottom, "Click on empty bottom area must return false")

        // Far outside local bounds (x: 500, y: 100)
        let hitFarOutside = model.dispatchHitTest(at: CGPoint(x: 500, y: 100), windowSize: testWindowSize)
        XCTAssertFalse(hitFarOutside, "Click far outside bounds must return false")
    }

    @MainActor
    func testCaretPillWindow_HandleMouseDownDismissesOnSettingsAndMenuBar() {
        let win = CaretPillWindow.shared
        let model = CaretHUDModel.shared
        let controller = BentoSettingsWindowController.shared

        // Ensure window is set up
        let hudRect = CGRect(x: 300, y: 300, width: 460, height: 52)
        win.present(at: hudRect)
        XCTAssertTrue(win.isVisible)
        XCTAssertTrue(model.isHUDVisible)

        // Subtest A: Clicks outside HUD window frame return false without swallowing
        let outsideClick = CGPoint(x: 50, y: 50)
        let outsideResult = win.handleMouseDown(atScreenPoint: outsideClick)
        XCTAssertFalse(outsideResult, "Click outside HUD frame must return false")

        // Subtest B: Clicks inside BentoSettingsWindow frame dismiss HUD and return false
        if let settingsWindow = controller.window {
            controller.showWindow()
            let settingsFrame = settingsWindow.frame
            let clickInsideSettings = CGPoint(x: settingsFrame.midX, y: settingsFrame.midY)

            // Re-present HUD to ensure it's visible before test
            win.present(at: hudRect)
            XCTAssertTrue(model.isHUDVisible)

            let settingsResult = win.handleMouseDown(atScreenPoint: clickInsideSettings)
            XCTAssertFalse(settingsResult, "Click inside Bento settings must return false (never swallow)")
            XCTAssertFalse(model.isHUDVisible, "Click inside Bento settings must dismiss the HUD")

            // Close settings
            controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        }

        // Subtest C: Clicks in top 32pt Menu Bar strip dismiss HUD and return false
        let screen = NSScreen.main ?? NSScreen.screens.first
        if let sc = screen {
            win.present(at: hudRect)
            XCTAssertTrue(model.isHUDVisible)

            // Point within top 32pt (e.g. y = screen.maxY - 10)
            let menuBarClick = CGPoint(x: sc.frame.midX, y: sc.frame.maxY - 10)
            let menuBarResult = win.handleMouseDown(atScreenPoint: menuBarClick)
            XCTAssertFalse(menuBarResult, "Click in top 32pt Menu Bar strip must return false (never swallow)")
            XCTAssertFalse(model.isHUDVisible, "Click in Menu Bar strip must dismiss the HUD")
        }

        // Cleanup
        win.dismiss()
    }
}
