import XCTest
import AppKit
import SwiftUI
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

final class SystemResilienceAndLifecycleTests: XCTestCase {

    // MARK: - R1: Non-Blocking EventTap & Accessibility Handling

    func testNonBlockingAXBehaviorOnPermissiveElements() {
        // 1. Verify isNonTextInteractiveControl returns false for permissive text & container roles
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: nil))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: ""))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXWebArea"))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXGroup"))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXScrollArea"))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXTextField"))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXTextArea"))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXComboBox"))
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXSearchField"))

        // 2. Verify isNonTextInteractiveControl returns true ONLY for verified non-text interactive controls
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXButton"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXRadioButton"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXCheckBox"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXPopUpButton"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXMenuButton"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXSlider"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXScrollBar"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXSplitter"))
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: "AXColorWell"))

        // 3. In unit test environment where focused element is nil, verify permissive non-blocking fallback
        XCTAssertFalse(AccessibilityBridge.shared.isBlockedFromTyping(), "Nil focused element must not block typing")
        XCTAssertTrue(AccessibilityBridge.shared.isFocusedElementEditableTextInput(), "Nil focused element must be permissive")
    }

    // MARK: - R2: Leaked SecureEventInput Isolation

    func testSecureEventInputIsolationMetadata() {
        // 1. Positive identification: AXSecureTextField or password descriptions
        let isSecureRole = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: "AXSecureTextField",
            description: nil,
            placeholder: nil,
            value: nil,
            isSystemSecureInput: false
        )
        XCTAssertTrue(isSecureRole)

        let isPasswordDesc = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: "Nhập mật khẩu của bạn",
            placeholder: nil,
            value: nil,
            isSystemSecureInput: false
        )
        XCTAssertTrue(isPasswordDesc)

        let isPinPlaceholder = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: nil,
            placeholder: "Mã PIN xác thực",
            value: nil,
            isSystemSecureInput: false
        )
        XCTAssertTrue(isPinPlaceholder)

        let isBulletValue = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: nil,
            placeholder: nil,
            value: "••••••••",
            isSystemSecureInput: false
        )
        XCTAssertTrue(isBulletValue)

        // 2. Negative identification: normal text fields with plaintext values
        let isNormalText = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: "Họ và tên",
            placeholder: "Nguyễn Văn A",
            value: "Nguyễn Văn A",
            isSystemSecureInput: false
        )
        XCTAssertFalse(isNormalText)

        // 3. Cache invalidation safety
        AccessibilityBridge.shared.invalidateCache()
    }

    func testAccessibilityBridgeCacheDecouplingAndIndependence() {
        let bridge = AccessibilityBridge.shared

        // 1. Initial invalidation: both caches must be inactive
        bridge.invalidateCache()
        XCTAssertFalse(bridge.isSecureCacheActive, "Secure cache must be inactive after invalidateCache()")
        XCTAssertFalse(bridge.isBlockedCacheActive, "Blocked cache must be inactive after invalidateCache()")

        // 2. Querying isFocusedElementSecureOrHidden populates ONLY secure cache
        _ = bridge.isFocusedElementSecureOrHidden()
        XCTAssertTrue(bridge.isSecureCacheActive, "Secure cache must be active after querying isFocusedElementSecureOrHidden()")
        XCTAssertFalse(bridge.isBlockedCacheActive, "Blocked cache must remain unpopulated when only secure was queried")

        // 3. Querying isBlockedFromTyping populates blocked cache without clobbering secure cache
        _ = bridge.isBlockedFromTyping()
        XCTAssertTrue(bridge.isSecureCacheActive, "Secure cache must remain active")
        XCTAssertTrue(bridge.isBlockedCacheActive, "Blocked cache must become active after query")

        // 4. Invalidate again
        bridge.invalidateCache()
        XCTAssertFalse(bridge.isSecureCacheActive)
        XCTAssertFalse(bridge.isBlockedCacheActive)

        // 5. Querying isBlockedFromTyping FIRST populates ONLY blocked cache
        _ = bridge.isBlockedFromTyping()
        XCTAssertTrue(bridge.isBlockedCacheActive, "Blocked cache must be active after querying isBlockedFromTyping()")
        XCTAssertFalse(bridge.isSecureCacheActive, "Secure cache must remain unpopulated when only blocked was queried")

        // 6. Querying isFocusedElementSecureOrHidden SECOND populates secure cache independently
        _ = bridge.isFocusedElementSecureOrHidden()
        XCTAssertTrue(bridge.isSecureCacheActive, "Secure cache must become active after query")
        XCTAssertTrue(bridge.isBlockedCacheActive, "Blocked cache must remain active")

        // 7. Cleanup
        bridge.invalidateCache()
        XCTAssertFalse(bridge.isSecureCacheActive)
        XCTAssertFalse(bridge.isBlockedCacheActive)
    }

    // MARK: - R3: Resilient EventTap Lifecycle & Recovery

    func testEventTapLifecycleAndMachPortValidation() {
        let hook = EventTapHook.shared

        let isTrusted = AccessibilityBridge.shared.isAccessibilityGranted(prompt: false)
        let restarted = hook.restart()
        XCTAssertEqual(restarted, isTrusted, "restart() status must match accessibility authorization")
        XCTAssertEqual(hook.isTapActive, isTrusted, "isTapActive must match accessibility authorization")

        // Test teardown with stop()
        hook.stop()
        XCTAssertFalse(hook.isTapActive, "isTapActive must be false after stop()")

        // Verify start restores state matching permissions
        _ = hook.start()
        XCTAssertEqual(hook.isTapActive, isTrusted, "isTapActive must match accessibility authorization after start()")

        // Consecutive restarts should not leak run loop sources or crash
        for _ in 0..<3 {
            _ = hook.restart()
        }
    }

    // MARK: - R5: Window Management, Menu Shortcuts & Activation Policy

    @MainActor
    func testBentoSettingsWindowActivationPolicyAndLifecycle() {
        let controller = BentoSettingsWindowController.shared
        let store = VFlowControlCenterStore.shared

        // 1. Presenting settings window promotes policy to .regular
        controller.showWindow()
        XCTAssertEqual(NSApp.activationPolicy(), .regular, "Activation policy must be .regular when settings window is shown")

        // 2. Telemetry polling must be active when window is open
        store.startTelemetryPolling()
        XCTAssertTrue(store.isTelemetryPollingActive, "Telemetry polling should be active when window is shown")

        // 3. Closing window restores policy to .accessory and stops telemetry polling
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        XCTAssertEqual(NSApp.activationPolicy(), .accessory, "Activation policy must revert to .accessory on window close")
        XCTAssertFalse(store.isTelemetryPollingActive, "Telemetry polling should be stopped when window closes")
    }

    @MainActor
    func testCaretPillWindowFloatingLevelAndHitTest() {
        let win = CaretPillWindow.shared

        // 1. Window level must be .floating (level 3, not .popUpMenu 101)
        XCTAssertEqual(win.level, .floating, "CaretPillWindow level must be .floating")

        // 2. dispatchHitTest returns false on non-chip background clicks
        let hit = CaretHUDModel.shared.dispatchHitTest(
            at: CGPoint(x: 20, y: 20),
            windowSize: CGSize(width: 460, height: 52)
        )
        XCTAssertFalse(hit, "dispatchHitTest must return false when no interactive chip is hit")

        // 3. handleMouseDown on Menu Bar top strip dismisses and returns false
        let screen = NSScreen.main ?? NSScreen.screens.first
        if let sc = screen {
            let menuBarClick = CGPoint(x: sc.frame.midX, y: sc.frame.maxY - 10)
            let result = win.handleMouseDown(atScreenPoint: menuBarClick)
            XCTAssertFalse(result, "handleMouseDown in menu bar top strip must return false without swallowing")
        }
    }

    // MARK: - R6: Idle CPU Optimization

    @MainActor
    func testSilkSineWaveViewPausableState() {
        // 1. Direct view instantiation with isPaused
        let activeWave = SilkSineWaveView(state: .transcript, audioLevel: 0.8, isPaused: false)
        XCTAssertFalse(activeWave.isPaused)

        let pausedWave = SilkSineWaveView(state: .transcript, audioLevel: 0.1, isPaused: true)
        XCTAssertTrue(pausedWave.isPaused)

        // 2. CaretHUDModel dynamic wave pause computation
        let model = CaretHUDModel.shared

        // When HUD is hidden, wave is paused
        model.isHUDVisible = false
        XCTAssertTrue(model.isWavePaused, "Wave must be paused when HUD is hidden")

        // When HUD is visible and audioLevel <= 0.25 in transcript state, wave is paused
        model.isHUDVisible = true
        model.state = .transcript
        model.audioLevel = 0.20
        XCTAssertTrue(model.isWavePaused, "Wave must be paused when motionless (audioLevel <= 0.25)")

        // When HUD is visible and audioLevel > 0.25, wave is animating (unpaused)
        model.audioLevel = 0.50
        XCTAssertFalse(model.isWavePaused, "Wave must be active when typing (audioLevel > 0.25)")

        // When HUD is visible in .working state (AI polish / voice dictation), wave is active
        model.state = .working
        model.audioLevel = 0.10
        XCTAssertFalse(model.isWavePaused, "Wave must be active when in .working state")

        // Cleanup
        model.isHUDVisible = false
    }

    @MainActor
    func testControlCenterStoreTelemetryLifecycle() {
        let store = VFlowControlCenterStore.shared
        store.stopTelemetryPolling()
        XCTAssertFalse(store.isTelemetryPollingActive)

        store.startTelemetryPolling()
        XCTAssertTrue(store.isTelemetryPollingActive)

        store.stopTelemetryPolling()
        XCTAssertFalse(store.isTelemetryPollingActive)
    }
}
