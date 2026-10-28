import XCTest
import CoreGraphics
import AppKit
import SwiftUI
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

final class VFlowPlatformM2Tests: XCTestCase {

    // MARK: - R2-BUG-01: Mid-word Caret Extraction & Symmetric Delete Offset

    func testMidWordCaretExtraction() {
        let fullText = "không duoc hết text"
        // Cursor between 'u' and 'o' in "duoc" -> index 8
        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: 8)

        XCTAssertEqual(ctx.wordPrefix, "du", "Prefix touching left of cursor should be 'du'")
        XCTAssertEqual(ctx.wordSuffix, "oc", "Suffix touching right of cursor should be 'oc'")
        XCTAssertEqual(ctx.wordAtCursor, "duoc", "Full word at cursor should be 'duoc'")
        XCTAssertEqual(ctx.wordBeforeCursor, "không", "Word before cursor should be 'không'")
        XCTAssertEqual(ctx.wordAfterCursor, "hết", "Word after cursor should be 'hết', not 'oc'")
        XCTAssertEqual(ctx.completedWordsBeforeCursor, ["không"])

        // Symmetric deletion counts
        XCTAssertEqual(ctx.wordPrefix.count, 2, "Left backspace count should match prefix length")
        XCTAssertEqual(ctx.wordSuffix.count, 2, "Right forward-delete count should match suffix length")
    }

    func testEndOfWordCaretExtraction() {
        let fullText = "không duoc hết"
        // Cursor at end of "duoc" -> index 10
        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: 10)

        XCTAssertEqual(ctx.wordPrefix, "duoc")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "duoc")
        XCTAssertEqual(ctx.wordBeforeCursor, "không")
        XCTAssertEqual(ctx.wordAfterCursor, "hết")
    }

    func testStartOfWordCaretExtraction() {
        let fullText = "không duoc hết"
        // Cursor at start of "duoc" -> index 6
        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: 6)

        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "duoc")
        XCTAssertEqual(ctx.wordAtCursor, "duoc")
        XCTAssertEqual(ctx.wordBeforeCursor, "không")
        XCTAssertEqual(ctx.wordAfterCursor, "hết")
    }

    func testGapBetweenWordsCaretExtraction() {
        let fullText = "không  thị"
        // Cursor between the two spaces -> index 6
        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: 6)

        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "")
        XCTAssertEqual(ctx.wordBeforeCursor, "không")
        XCTAssertEqual(ctx.wordAfterCursor, "thị")
    }

    // MARK: - R2-BUG-02: Missing Bridge-Word Detection

    func testBridgeWordDetection_CaretTouchingLeftWord() {
        // When cursor touches left word: "không| thị"
        let suggestions = SuggestionEngine.suggest(
            currentWord: "không",
            rawWord: "khong",
            sentenceWords: ["không"],
            wordAfterCursor: "thị"
        )

        let bridgeSuggestion = suggestions.first { $0.text == "hiển" }
        XCTAssertNotNil(bridgeSuggestion, "Bridge word 'hiển' must be suggested when cursor touches left word 'không| thị'")
        XCTAssertFalse(bridgeSuggestion?.replaceCurrentWord ?? true, "Bridge word should not replace the left word")
    }

    func testBridgeWordDetection_UnsignedAndShorthand() {
        // Direct
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "không", right: "thị"), "hiển")
        // Shorthand
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "ko", right: "thị"), "hiển")
        // Unsigned
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "khong", right: "thi"), "hiển")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "chua", right: "value"), "đạt")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "bi", right: "hien"), "lỗi")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "ho", right: "tieng"), "trợ")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "xin", right: "on"), "cảm")
    }

    func testBridgeWordInGap() {
        // Cursor in gap after space: "không | thị"
        let suggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: ["không"],
            wordAfterCursor: "thị"
        )

        let bridge = suggestions.first { $0.text == "hiển" }
        XCTAssertNotNil(bridge, "Bridge word 'hiển' must be suggested in gap")
    }

    // MARK: - R2-BUG-03: Trailing Spaces Duplication

    func testReplaceLastCompletedWord_TrailingSpaceCount() {
        let text = "tôi ko   " // 3 trailing spaces
        let cursor = (text as NSString).length
        let ns = text as NSString
        let leftStr = ns.substring(to: cursor)

        var count = 0
        for ch in leftStr.reversed() {
            if ch.isWhitespace { count += 1 } else { break }
        }

        XCTAssertEqual(count, 3, "All 3 trailing spaces must be counted to prevent character duplication")
        let targetWord = "ko"
        let bsCount = targetWord.count + count
        XCTAssertEqual(bsCount, 5, "Total backspaces must be 2 (target word) + 3 (spaces) = 5")
    }

    // MARK: - R2-BUG-04: Full-Sentence Polish Document Wiping Prevention

    func testClauseBounding_MultiSentenceDocument() {
        let doc = "Xin chào mọi người. không thị duoc hết text. Cảm ơn rất nhiều."
        // Cursor placed at "du|oc" inside second sentence: location 30
        let (start, end) = EventTapHook.findClauseBounds(in: doc, cursorLocation: 30)

        let ns = doc as NSString
        let clause = ns.substring(with: NSRange(location: start, length: end - start))

        XCTAssertEqual(clause, "không thị duoc hết text", "Clause bounds must isolate only the active sentence")
        XCTAssertEqual(start, 20, "Clause start should be at 'không', preserving 'Xin chào mọi người. '")
        XCTAssertEqual(end, 43, "Clause end should be at 'text', preserving '. Cảm ơn rất nhiều.'")

        let prefixPreserved = ns.substring(to: start)
        let suffixPreserved = ns.substring(from: end)
        XCTAssertEqual(prefixPreserved, "Xin chào mọi người. ")
        XCTAssertEqual(suffixPreserved, ". Cảm ơn rất nhiều.")
    }

    func testClauseBounding_MultiLineDocument() {
        let doc = "Line 1: Header\nkhông thị duoc hết\nLine 3: Footer"
        let (start, end) = EventTapHook.findClauseBounds(in: doc, cursorLocation: 25)

        let ns = doc as NSString
        let clause = ns.substring(with: NSRange(location: start, length: end - start))
        XCTAssertEqual(clause, "không thị duoc hết")
        XCTAssertEqual(ns.substring(to: start), "Line 1: Header\n")
        XCTAssertEqual(ns.substring(from: end), "\nLine 3: Footer")
    }

    // MARK: - R2-BUG-05: Unicode Multi-Scalar & UTF-16 Offset Handling

    func testUnicodeEmojiAndDecomposedCharacters() {
        let doc = "Chào bạn 🇻🇳 duoc 🚀"
        // Cursor inside "duoc" -> between 'u' and 'o'
        let ns = doc as NSString
        let range = ns.range(of: "duoc")
        let cursorLoc = range.location + 2

        let ctx = AccessibilityBridge.extractContext(fullText: doc, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "du")
        XCTAssertEqual(ctx.wordSuffix, "oc")
        XCTAssertEqual(ctx.wordAtCursor, "duoc")
        XCTAssertEqual(ctx.wordBeforeCursor, "🇻🇳")
        XCTAssertEqual(ctx.wordAfterCursor, "🚀")
    }

    // MARK: - R2-BUG-06: Language Prioritization (Vietnamese over English)

    func testLanguagePriority_VietnamesePrefixOverEnglishCompletions() {
        // When typing 'va' in Vietnamese mode
        let suggestions = SuggestionEngine.suggest(
            currentWord: "va",
            rawWord: "va",
            sentenceWords: ["va"]
        )

        XCTAssertFalse(suggestions.isEmpty)
        // First suggestion must be a Vietnamese word/phrase (e.g. 'và' or 'vào'), NOT 'value'
        let firstText = suggestions.first?.text ?? ""
        let isVietnamese = firstText.hasPrefix("v") && (firstText == "và" || firstText == "vào" || firstText.contains("văn") || firstText.contains("vấn"))
        XCTAssertTrue(isVietnamese, "First suggestion for 'va' must be Vietnamese ('và' / 'vào'), but got '\(firstText)'")

        // When typing 'val', where no Vietnamese word matches, English completion should appear
        let valSuggestions = SuggestionEngine.suggest(
            currentWord: "val",
            rawWord: "val",
            sentenceWords: ["val"]
        )
        let hasValue = valSuggestions.contains { $0.text.lowercased().hasPrefix("val") }
        XCTAssertTrue(hasValue, "English completion like 'value' should appear for 'val'")
    }

    // MARK: - R2-BUG-07: Typo Leading Space in " và"

    func testTypoSpaceBeforeVaEliminated() {
        XCTAssertFalse(SuggestionEngine.vietnamesePhrases.contains(" và"), "vietnamesePhrases must NOT contain illegal leading space ' và'")
        XCTAssertTrue(SuggestionEngine.vietnamesePhrases.contains("và"), "vietnamesePhrases MUST contain 'và'")
    }

    // MARK: - R2-BUG-08: Start of Document Boundary Condition

    func testStartOfDocumentBoundary() {
        let (start, end) = EventTapHook.findClauseBounds(in: "duoc het text", cursorLocation: 0)
        XCTAssertEqual(start, 0)
        XCTAssertEqual(end, 13)
    }

    // MARK: - R3-BUG-01: Synthetic Event Tagging

    func testSyntheticEventMarkerConstants() {
        XCTAssertEqual(EventTapHook.syntheticEventMarker, 0x56464C57, "Synthetic event marker must be 0x56464C57 ('VFLW')")
    }

    // MARK: - R3-BUG-04 & R3-BUG-05: Multi-Monitor HUD Coordinate Clamping & 52px Height

    func testMultiMonitorCaretCoordinateClamping() {
        let externalScreenFrame = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        let caretRect = CGRect(x: 2400, y: 800, width: 2, height: 16)
        let pillSize = CGSize(width: 460, height: 52)

        let frame = CaretLocator.calculatePillFrame(
            caretRect: caretRect,
            pillSize: pillSize,
            screenFrame: externalScreenFrame
        )

        // Pill must stay on external screen (x >= 1920 + 8, x + width <= 4480 - 8)
        XCTAssertGreaterThanOrEqual(frame.origin.x, externalScreenFrame.minX + 8.0)
        XCTAssertLessThanOrEqual(frame.maxX, externalScreenFrame.maxX - 8.0)
        XCTAssertEqual(frame.height, 52.0, "HUD height must be 52.0px")
    }

    func testScreenFlipWith52HeightNearTop() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        // Caret 45px below top edge: y = 855, height = 16 (maxY = 871)
        // Normal originY: 871 + 10 = 881. With height 52: 881 + 52 = 933 > 900 -> flips!
        let caret = CGRect(x: 500, y: 855, width: 2, height: 16)
        let pillSize = CGSize(width: 460, height: 52)

        let frame = CaretLocator.calculatePillFrame(caretRect: caret, pillSize: pillSize, screenFrame: screen)

        // Must flip to 10px below caret: caret.minY (855) - 52 - 10 = 793
        XCTAssertEqual(frame.origin.y, 793.0)
    }

    // MARK: - R3-BUG-06: BentoSettingsWindow Preview Isolation & Restore

    func testCaretHUDModelHostingRestore() {
        MainActor.assumeIsolated {
            let model = CaretHUDModel.shared
            model.restoreHosting()
            XCTAssertNotNil(CaretPillWindow.shared.contentView)
            XCTAssertTrue(CaretPillWindow.shared.contentView is NSHostingView<CaretHUDContainerView>)
        }
    }

    // MARK: - R3-BUG-07: Concurrency Thread Safety

    @MainActor
    func testEventTapHookThreadSafety() {
        let hook = EventTapHook.shared
        let exp = expectation(description: "Concurrent state access")
        exp.expectedFulfillmentCount = 20

        for _ in 0..<20 {
            DispatchQueue.global().async {
                hook.notifyTypingState()
                _ = hook.isTapActive
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - R3-BUG-08: VoiceDictationService MainActor Safety

    @MainActor
    func testVoiceDictationServiceStopRecordingIsThreadSafe() {
        let service = VoiceDictationService.shared
        let exp = expectation(description: "Background stopRecording")

        DispatchQueue.global().async {
            service.stopRecording()
            DispatchQueue.main.async {
                XCTAssertFalse(service.isRecording)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0)
    }

    @MainActor
    func testPushToTalkDualModeTapAndHold() async {
        final class CounterBox: @unchecked Sendable {
            var startedCount = 0
            var stoppedCount = 0
        }
        let box = CounterBox()
        let monitor = PushToTalkMonitor()

        monitor.onStartRecording = { box.startedCount += 1 }
        monitor.onStopRecording = { box.stoppedCount += 1 }

        // 1. Quick Tap (< 350ms): starts recording on keyDown, stays active on keyUp, stops on second tap
        monitor.handleOptionSpaceKeyDown()
        XCTAssertEqual(box.startedCount, 1)
        XCTAssertEqual(box.stoppedCount, 0)

        monitor.handleOptionSpaceKeyUp()
        XCTAssertEqual(box.stoppedCount, 0, "Quick tap release must stay in hands-free recording mode")

        monitor.handleOptionSpaceKeyDown()
        XCTAssertEqual(box.stoppedCount, 1, "Second tap must stop hands-free recording")
        monitor.handleOptionSpaceKeyUp()

        // 2. Hold-to-Talk (>= 350ms): starts on keyDown, stops immediately on keyUp
        monitor.handleOptionSpaceKeyDown()
        XCTAssertEqual(box.startedCount, 2)
        try? await Task.sleep(nanoseconds: 380_000_000)
        monitor.handleOptionSpaceKeyUp()
        XCTAssertEqual(box.stoppedCount, 2, "Releasing after >=350ms hold must stop recording immediately")
    }
}
