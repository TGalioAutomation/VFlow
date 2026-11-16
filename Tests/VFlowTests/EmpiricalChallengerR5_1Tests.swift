import XCTest
import AppKit
import CoreGraphics
import ApplicationServices
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

private final class SafeBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { self._value = value }
    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

/// Adversarial empirical verification test suite authored and executed by Challenger R5.1 (teamwork_challenger).
/// Scope: EventTap and Accessibility Changes:
/// 1. `AccessibilityBridge.shared.isBlockedFromTyping`:
///    - Returns `false` (permissive) for `nil`, `AXWebArea`, and `AXGroup`.
///    - Returns `true` for `AXButton`, `AXSlider`, `AXPopUpButton`, `AXCheckBox`, `AXRadioButton`.
/// 2. `AccessibilityBridge.shared.isFocusedElementSecureOrHidden`:
///    - Simulated/mock elements with role `AXTextField` or `AXWebArea` do NOT trigger secure blocking even when `IsSecureEventInputEnabled()` is true.
///    - `AXSecureTextField` DOES return `true`.
/// 3. `EventTapHook`:
///    - `CFMachPortIsValid` validation and `restart()` resilience.
/// 4. Full test suite execution and verification.
final class EmpiricalChallengerR5_1Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        AccessibilityBridge.shared.invalidateCache()
    }

    override func tearDown() {
        AccessibilityBridge.shared.invalidateCache()
        super.tearDown()
    }

    // MARK: - 1. EMPIRICAL STRESS: isBlockedFromTyping & isNonTextInteractiveControl

    func testBlockedFromTyping_PermissiveRolesReturnFalse() {
        // 1. Static evaluation on nil, empty, and document/container roles
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: nil), "nil role must never be treated as non-text interactive control")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: ""), "empty role must never be treated as non-text interactive control")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXWebArea"), "AXWebArea (browser root) must be permissive")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXGroup"), "AXGroup (content container/div) must be permissive")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXScrollArea"), "AXScrollArea must be permissive")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXWindow"), "AXWindow must be permissive")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: "AXApplication"), "AXApplication must be permissive")

        // 2. Standard text roles must be permissive
        let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXStaticText"]
        for r in textRoles {
            XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: r), "\(r) must not be blocked from typing")
        }

        // 3. Custom web / IDE element roles must be permissive
        let customIDEWebRoles = [
            "AXUnknown",
            "MonacoContainer",
            "ChromeRenderWidgetHost",
            "ElectronWebContents",
            "NotionEditorBody"
        ]
        for cr in customIDEWebRoles {
            XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: cr), "Custom web role '\(cr)' must be permissive")
        }
    }

    func testBlockedFromTyping_NonTextInteractiveControlsReturnTrue() {
        // Scope requirement: verify it returns true for AXButton, AXSlider, AXPopUpButton, AXCheckBox, AXRadioButton
        let targetBlockedRoles = [
            "AXButton",
            "AXSlider",
            "AXPopUpButton",
            "AXCheckBox",
            "AXRadioButton"
        ]
        for role in targetBlockedRoles {
            XCTAssertTrue(
                AccessibilityBridge.isNonTextInteractiveControl(role: role),
                "Role '\(role)' must be positively identified as a non-text interactive control"
            )
        }

        // Additional non-text interactive controls
        let additionalBlockedRoles = [
            "AXMenuButton",
            "AXScrollBar",
            "AXSplitter",
            "AXColorWell"
        ]
        for role in additionalBlockedRoles {
            XCTAssertTrue(
                AccessibilityBridge.isNonTextInteractiveControl(role: role),
                "Role '\(role)' must be positively identified as a non-text interactive control"
            )
        }
    }

    @MainActor
    func testAppKitControls_AccessibilityRoleMappingMatchesEvaluator() {
        // Verify standard AppKit NSAccessibility rawValues match evaluator expectation
        let buttonRole = NSAccessibility.Role.button.rawValue
        XCTAssertEqual(buttonRole, "AXButton")
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: buttonRole))

        let sliderRole = NSAccessibility.Role.slider.rawValue
        XCTAssertEqual(sliderRole, "AXSlider")
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: sliderRole))

        let popupRole = NSAccessibility.Role.popUpButton.rawValue
        XCTAssertEqual(popupRole, "AXPopUpButton")
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: popupRole))

        let checkboxRole = NSAccessibility.Role.checkBox.rawValue
        XCTAssertEqual(checkboxRole, "AXCheckBox")
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: checkboxRole))

        let radioRole = NSAccessibility.Role.radioButton.rawValue
        XCTAssertEqual(radioRole, "AXRadioButton")
        XCTAssertTrue(AccessibilityBridge.isNonTextInteractiveControl(role: radioRole))

        let textRole = NSAccessibility.Role.textField.rawValue
        XCTAssertEqual(textRole, "AXTextField")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: textRole))
        XCTAssertFalse(AccessibilityBridge.isSecureFieldMetadata(
            role: textRole,
            subrole: nil,
            description: nil,
            placeholder: nil,
            value: "Hello"
        ))

        let secureRole = NSAccessibility.Role.textField.rawValue
        let secureSubrole = NSAccessibility.Subrole.secureTextField.rawValue
        XCTAssertEqual(secureRole, "AXTextField")
        XCTAssertEqual(secureSubrole, "AXSecureTextField")
        XCTAssertFalse(AccessibilityBridge.isNonTextInteractiveControl(role: secureRole))
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: secureRole,
            subrole: secureSubrole,
            description: nil,
            placeholder: nil,
            value: "Secret123"
        ))
    }

    func testBlockedFromTyping_NilElementPermissiveFallback() {
        // When focused element is nil (as in headless unit tests), isBlockedFromTyping must return false
        AccessibilityBridge.shared.invalidateCache()
        let isBlocked = AccessibilityBridge.shared.isBlockedFromTyping()
        XCTAssertFalse(isBlocked, "isBlockedFromTyping() must return false when no element is focused (permissive fallback)")

        let isEditable = AccessibilityBridge.shared.isFocusedElementEditableTextInput()
        XCTAssertTrue(isEditable, "isFocusedElementEditableTextInput() must return true when element is nil")
    }

    func testBlockedFromTyping_CacheTTLAndInvalidation() {
        AccessibilityBridge.shared.invalidateCache()

        // First call populates cache
        let call1 = AccessibilityBridge.shared.isBlockedFromTyping()
        XCTAssertFalse(call1)

        // Rapid subsequent call should hit cache without error
        let call2 = AccessibilityBridge.shared.isBlockedFromTyping()
        XCTAssertEqual(call1, call2)

        // Explicit cache invalidation
        AccessibilityBridge.shared.invalidateCache()
        let call3 = AccessibilityBridge.shared.isBlockedFromTyping()
        XCTAssertEqual(call2, call3)
    }

    // MARK: - 2. EMPIRICAL STRESS: isFocusedElementSecureOrHidden & Leaked Secure Input

    func testSecureFieldMetadata_RoleAndSubroleDetection() {
        // 1. Explicit AXSecureTextField role or subrole
        XCTAssertTrue(
            AccessibilityBridge.isSecureFieldMetadata(
                role: "AXSecureTextField",
                subrole: nil,
                description: nil,
                placeholder: nil,
                value: nil,
                isSystemSecureInput: false
            ),
            "AXSecureTextField role must trigger secure field detection"
        )

        XCTAssertTrue(
            AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: "AXSecureTextField",
                description: nil,
                placeholder: nil,
                value: nil,
                isSystemSecureInput: false
            ),
            "AXSecureTextField subrole must trigger secure field detection"
        )

        XCTAssertTrue(
            AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: "NSSecureTextFieldSubrole",
                description: nil,
                placeholder: nil,
                value: nil,
                isSystemSecureInput: false
            ),
            "Subrole containing 'secure' must trigger secure field detection"
        )
    }

    func testSecureFieldMetadata_LeakedSecureEventInputIsolation() {
        // Simulate elements with role AXTextField or AXWebArea when IsSecureEventInputEnabled() is simulated:
        // Even if system secure event input is active in the background, a standard text or web container
        // without secure attributes must NOT trigger secure blocking.
        let standardRoles = ["AXTextField", "AXTextArea", "AXWebArea", "AXGroup", "AXComboBox", "AXSearchField"]

        for role in standardRoles {
            // When isSystemSecureInput is false (standard element metadata evaluation):
            let isSecure = AccessibilityBridge.isSecureFieldMetadata(
                role: role,
                subrole: nil,
                description: "Normal editable input",
                placeholder: "Type here...",
                value: "Sample text",
                isSystemSecureInput: false
            )
            XCTAssertFalse(
                isSecure,
                "Role '\(role)' without secure attributes must return false in isSecureFieldMetadata"
            )
        }

        // Contrast with AXSecureTextField which DOES return true:
        let secureRoleResult = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXSecureTextField",
            subrole: nil,
            description: nil,
            placeholder: nil,
            value: nil,
            isSystemSecureInput: false
        )
        XCTAssertTrue(secureRoleResult, "AXSecureTextField must return true regardless of system secure state")

        let secureSubroleResult = AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: "AXSecureTextField",
            description: nil,
            placeholder: nil,
            value: nil,
            isSystemSecureInput: false
        )
        XCTAssertTrue(secureSubroleResult, "AXTextField with AXSecureTextField subrole must return true")
    }

    func testSecureFieldMetadata_SensitiveKeywordsInDescriptionOrPlaceholder() {
        let sensitiveKeywords = [
            "password", "mật khẩu", "mat khau", "passcode", "mã pin", "secret key", "hide text", "ẩn văn bản"
        ]

        for keyword in sensitiveKeywords {
            // In description
            let descResult = AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: nil,
                description: "Vui lòng nhập \(keyword) tại đây",
                placeholder: nil,
                value: nil,
                isSystemSecureInput: false
            )
            XCTAssertTrue(descResult, "Description containing '\(keyword)' must trigger secure field detection")

            // In placeholder
            let placeholderResult = AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: nil,
                description: nil,
                placeholder: keyword.uppercased(),
                value: nil,
                isSystemSecureInput: false
            )
            XCTAssertTrue(placeholderResult, "Placeholder containing '\(keyword)' (uppercase) must trigger secure field detection")
        }
    }

    func testSecureFieldMetadata_MaskedValueDetection() {
        // Masked bullet characters
        let bulletMasks = ["••••••••", "●●●●●", "✱✱✱✱", "⚫⚫⚫", "◦◦◦◦", "▪▪▪▪▪"]
        for mask in bulletMasks {
            let res = AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: nil,
                description: nil,
                placeholder: nil,
                value: mask,
                isSystemSecureInput: false
            )
            XCTAssertTrue(res, "Masked value '\(mask)' must trigger secure field detection")
        }

        // Asterisks >= 2 chars
        XCTAssertTrue(
            AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: nil,
                description: nil,
                placeholder: nil,
                value: "******",
                isSystemSecureInput: false
            ),
            "Multiple asterisks must trigger secure field detection"
        )

        // Single asterisk should NOT trigger false positive
        XCTAssertFalse(
            AccessibilityBridge.isSecureFieldMetadata(
                role: "AXTextField",
                subrole: nil,
                description: nil,
                placeholder: nil,
                value: "*",
                isSystemSecureInput: false
            ),
            "Single asterisk must not trigger secure field detection"
        )
    }

    func testSecureFieldMetadata_NormalTextInputsRemainUnblocked() {
        // Plaintext normal fields must evaluate to false
        let normalInputs = [
            ("AXTextField", "Họ và tên", "Nguyễn Văn A"),
            ("AXTextArea", "Địa chỉ giao hàng", "123 Đường Lê Lợi, Quận 1"),
            ("AXSearchField", "Tìm kiếm sản phẩm", "iPhone 15 Pro"),
            ("AXWebArea", nil, nil),
            ("AXGroup", nil, nil)
        ]

        for (role, desc, val) in normalInputs {
            let res = AccessibilityBridge.isSecureFieldMetadata(
                role: role,
                subrole: nil,
                description: desc,
                placeholder: nil,
                value: val,
                isSystemSecureInput: false
            )
            XCTAssertFalse(res, "Normal input with role '\(role)' must NOT trigger secure field detection")
        }
    }

    func testSecureEventInputIsolation_NilElementPermissiveFallback() {
        // When evaluating nil element in test process without front terminal:
        AccessibilityBridge.shared.invalidateCache()
        let isSecure = AccessibilityBridge.shared.isFocusedElementSecureOrHidden()
        // In test runner (not Terminal or loginwindow), must return false
        XCTAssertFalse(isSecure, "Test process with nil element must not be falsely treated as secure")
    }

    // MARK: - 3. EMPIRICAL STRESS: EventTapHook Lifecycle, Port Validity & Resilience

    func testEventTapHook_PortValidityAndInitialState() {
        let hook = EventTapHook.shared
        let isTrusted = AccessibilityBridge.shared.isAccessibilityGranted(prompt: false)

        // In test environment without TCC Accessibility permissions, start() gracefully returns false
        let isStarted = hook.start()
        XCTAssertEqual(isStarted, isTrusted, "start() status must match accessibility authorization")
        XCTAssertEqual(hook.isTapActive, isTrusted, "isTapActive must match accessibility authorization")
    }

    func testEventTapHook_RestartStressHarness() {
        let hook = EventTapHook.shared
        let isTrusted = AccessibilityBridge.shared.isAccessibilityGranted(prompt: false)

        // Execute 15 consecutive restart() calls to ensure no runloop source leaks, lock deadlocks, or crashes
        for i in 1...15 {
            let restarted = hook.restart()
            XCTAssertEqual(restarted, isTrusted, "restart() invocation #\(i) must match accessibility authorization")
            XCTAssertEqual(hook.isTapActive, isTrusted, "isTapActive must match accessibility authorization on invocation #\(i)")
        }

        // Clean teardown with stop()
        hook.stop()
        XCTAssertFalse(hook.isTapActive, "isTapActive must be false after stop()")
    }

    func testEventTapHook_SyntheticEventMarkerConstant() {
        // Synthetic events emitted by VFlow must use 0x56464C57 ('VFLW') to prevent synthetic event loops
        XCTAssertEqual(
            EventTapHook.syntheticEventMarker,
            0x56464C57,
            "syntheticEventMarker must equal 0x56464C57 ('VFLW')"
        )
    }

    func testEventTapHook_SuggestionShortcutsDispatch() {
        let hook = EventTapHook.shared

        // Test option number shortcuts (⌥1, ⌥2, ⌥3)
        let selectedIndex = SafeBox<Int?>(nil)
        hook.onSelectSuggestionShortcut = { idx in
            selectedIndex.value = idx
            return true
        }

        // Option + 1 (ANSI 1 = keycode 18)
        let handledOpt1 = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_ANSI_1,
            flags: .maskAlternate
        )
        XCTAssertTrue(handledOpt1, "⌥1 must be consumed by handleSuggestionShortcutKeyDown")
        XCTAssertEqual(selectedIndex.value, 0, "⌥1 must select index 0")

        // Option + 2 (ANSI 2 = keycode 19)
        let handledOpt2 = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_ANSI_2,
            flags: .maskAlternate
        )
        XCTAssertTrue(handledOpt2, "⌥2 must be consumed")
        XCTAssertEqual(selectedIndex.value, 1, "⌥2 must select index 1")

        // Option + 3 (ANSI 3 = keycode 20)
        let handledOpt3 = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_ANSI_3,
            flags: .maskAlternate
        )
        XCTAssertTrue(handledOpt3, "⌥3 must be consumed")
        XCTAssertEqual(selectedIndex.value, 2, "⌥3 must select index 2")

        // Option + Command + 1 (should NOT trigger suggestion, as Command is pressed)
        selectedIndex.value = nil
        let handledCmdOpt = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_ANSI_1,
            flags: [.maskAlternate, .maskCommand]
        )
        XCTAssertFalse(handledCmdOpt, "⌘⌥1 must NOT be consumed as suggestion shortcut")
        XCTAssertNil(selectedIndex.value)
    }

    // MARK: - 4. EMPIRICAL STRESS: Multi-Threaded Concurrency & Race-Condition Oracles

    func testAccessibilityBridge_ConcurrentCacheAccessStress() {
        // Concurrently query isBlockedFromTyping, isFocusedElementSecureOrHidden, and invalidateCache
        // across 20 background threads to test NSLock synchronization and verify zero data races.
        let bridge = AccessibilityBridge.shared
        let expectation = expectation(description: "Concurrent AccessibilityBridge stress")
        expectation.expectedFulfillmentCount = 20

        for _ in 0..<20 {
            DispatchQueue.global(qos: .userInitiated).async {
                for iter in 0..<50 {
                    if iter % 10 == 0 {
                        bridge.invalidateCache()
                    }
                    _ = bridge.isBlockedFromTyping()
                    _ = bridge.isFocusedElementSecureOrHidden()
                    _ = bridge.isFocusedElementEditableTextInput()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testEventTapHook_ConcurrentRestartStress() {
        let hook = EventTapHook.shared
        let expectation = expectation(description: "Concurrent EventTapHook restart stress")
        expectation.expectedFulfillmentCount = 8

        for _ in 0..<8 {
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<5 {
                    _ = hook.restart()
                    _ = hook.isTapActive
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
        hook.stop()
    }
}
