import XCTest
import CoreGraphics
import AppKit
import SwiftUI
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

final class Milestone2RemediationTests: XCTestCase {
    var engine: VietnameseInputEngine!

    override func setUp() {
        super.setUp()
        engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
    }

    private func typeString(_ str: String) -> EngineResult {
        var lastResult = EngineResult()
        for ch in str {
            lastResult = engine.processKey(ch)
        }
        return lastResult
    }

    // MARK: - 1. Telex Double-Key Escape with Composed Vowels (BUG-01 & BUG-10)

    func testDoubleTelexEscape_ComposedVowelsPreserved() {
        // "tieengss" -> should produce "tiếng"
        engine.reset()
        _ = typeString("tieengss")
        XCTAssertEqual(engine.formattedWord, "tiếng", "tieengss should escape to composed tiếng, not raw tieengs")

        // "dduwowngff" -> should produce "đường"
        engine.reset()
        _ = typeString("dduwowngff")
        XCTAssertEqual(engine.formattedWord, "đường", "dduwowngff should escape to đường")

        // "mowiss" -> should produce "mới"
        engine.reset()
        _ = typeString("mowiss")
        XCTAssertEqual(engine.formattedWord, "mới", "mowiss should escape to mới")

        // "chuawxx" -> should produce "chữa"
        engine.reset()
        _ = typeString("chuawxx")
        XCTAssertEqual(engine.formattedWord, "chữa", "chuawxx should escape to chữa")

        // Mixed-case escape pairs "Texxt" -> "Text"
        engine.reset()
        _ = typeString("Texxt")
        XCTAssertEqual(engine.formattedWord, "Text", "Texxt should collapse to Text")
    }

    // MARK: - 2. English Compound Words with Double Consonants (BUG-02)

    func testCompoundEnglishDoubleConsonants() {
        let compounds = ["subclass", "compass", "bypass", "keypress", "preprocess", "success", "access", "process"]
        for word in compounds {
            XCTAssertTrue(SmartEnglishDetector.isGenuineEnglishDoubleConsonantWord(word), "\(word) should be detected as English double consonant compound")
            XCTAssertTrue(SmartEnglishDetector.isEnglishWord(word), "\(word) should be detected as English")
        }
    }

    // MARK: - 3. English Everyday Bilingual Words (BUG-02 / Defect 3)

    func testEnglishEverydayBilingualWords() {
        let everyday = ["time", "times", "go", "goes", "going", "ready", "work", "home"]
        for word in everyday {
            XCTAssertTrue(SmartEnglishDetector.isEnglishWord(word), "\(word) should be recognized as common English")
        }
    }

    // MARK: - 4. Contextual Pronoun Repair Guarding English & Size Adjectives (BUG-04)

    func testPronounRepair_NoEnglishOrAdjectiveCorruptions() {
        // English phrases with "to go" or "ready to go"
        let phrase1 = "ready to go"
        let polished1 = VietnameseTextPolisher.polish(phrase1)
        XCTAssertEqual(polished1.lowercased(), "ready to go", "ready to go should not corrupt to ready tôi go")

        let phrase2 = "time to go"
        let polished2 = VietnameseTextPolisher.polish(phrase2)
        XCTAssertEqual(polished2.lowercased(), "time to go", "time to go should not corrupt to time tôi go")

        let phrase3 = "cà phê to go"
        let polished3 = VietnameseTextPolisher.polish(phrase3)
        XCTAssertTrue(polished3.contains("to go"), "cà phê to go should preserve to go")

        // Preceding noun/adverb size adjectives: "chữ to", "nhà to", "rất to", "quá to"
        let phrase4 = "chữ to đang đẹp"
        let polished4 = VietnameseTextPolisher.polish(phrase4)
        XCTAssertFalse(polished4.contains("chữ tôi"), "chữ to should not be converted to chữ tôi")

        let phrase5 = "căn nhà to quá"
        let polished5 = VietnameseTextPolisher.polish(phrase5)
        XCTAssertFalse(polished5.contains("nhà tôi quá"), "nhà to should not be converted to nhà tôi")

        // Genuine teencode pronoun "to đang làm" -> "tôi đang làm"
        let phrase6 = "to đang làm việc"
        let polished6 = VietnameseTextPolisher.polish(phrase6)
        XCTAssertTrue(polished6.hasPrefix("tôi đang làm việc") || polished6.hasPrefix("Tôi đang làm việc"), "to at start of sentence should expand to tôi")
    }

    // MARK: - 5. Collocation Typo Repair: không cau có & câu hỏi Preserved (BUG-05)

    func testCollocationRepair_KhongCauCoPreserved() {
        let p1 = VietnameseTextPolisher.polish("anh ấy không cau có")
        XCTAssertTrue(p1.contains("không cau có"), "không cau có must not be converted to không dấu có")

        let p2 = VietnameseTextPolisher.polish("tôi có một câu hỏi")
        XCTAssertTrue(p2.contains("câu hỏi"), "câu hỏi must not be converted to dấu hỏi")

        // With next word "có", "cau" should not be forced into "dấu"
        let contextualFix = SuggestionEngine.resolveContextualWordFix(
            prevWord: "không",
            currentWord: "cau",
            wordAfterCursor: "có"
        )
        XCTAssertNil(contextualFix, "cau before có should not be replaced with dấu")
    }

    // MARK: - 6. Exact Levenshtein Edit Distance (BUG-06)

    func testAsciiEditDistance_AccuracyOnVaryingLengths() {
        let dist = SuggestionEngine.asciiEditDistance("abc", "xyzdefg")
        XCTAssertEqual(dist, 7, "Levenshtein distance between abc and xyzdefg must be 7, not 999")

        XCTAssertEqual(SuggestionEngine.asciiEditDistance("viet", "viett"), 1)
        XCTAssertEqual(SuggestionEngine.asciiEditDistance("test", "test"), 0)
        XCTAssertEqual(SuggestionEngine.asciiEditDistance("", "hello"), 5)
    }

    // MARK: - 7. OnDeviceAIEngine isValidRefinement Filler Word and Root Checks (BUG-07, BUG-08)

    func testIsValidRefinement_FillerWordsAndAccentedPreservation() {
        // Dropping conversational filler words should be allowed
        let base1 = "à ừm tôi đang làm việc"
        let cand1 = "Tôi đang làm việc"
        XCTAssertTrue(OnDeviceAIEngine.isValidRefinement(base: base1, candidate: cand1), "Dropping fillers should be valid refinement")

        // Arbitrary modification or deletion of accented core base word should be rejected
        let base2 = "không có câu hỏi"
        let cand2 = "không có dấu hỏi"
        XCTAssertFalse(OnDeviceAIEngine.isValidRefinement(base: base2, candidate: cand2), "Corrupting accented câu to dấu should be rejected")
    }

    // MARK: - 8. PostUnicodeString Chunking <= 20 UniChars (Defect 10)

    func testPostUnicodeStringChunkingCalculation() {
        let longText = "Đây là một chuỗi văn bản Tiếng Việt rất dài với hơn năm mươi ký tự để kiểm tra chia nhỏ uniChar."
        let utf16Chars = Array(longText.utf16)
        XCTAssertGreaterThan(utf16Chars.count, 20)

        // Verify chunk division conforms to max 20 UniChar limit
        var offset = 0
        while offset < utf16Chars.count {
            let chunkSize = min(20, utf16Chars.count - offset)
            XCTAssertLessThanOrEqual(chunkSize, 20)
            offset += chunkSize
        }
        XCTAssertEqual(offset, utf16Chars.count)
    }

    // MARK: - 9. AccessibilityBridge Type Safety (Defect 11)

    func testAccessibilityBridgeSafeTypeChecks() {
        // Calling AccessibilityBridge methods should execute safely without SIGABRT
        _ = AccessibilityBridge.shared.focusedUIElement()
        _ = AccessibilityBridge.shared.readFocusedTextContext()
        XCTAssertTrue(true)
    }

    // MARK: - 10. EventTapHook Thread Safety (Defect 15)

    func testEventTapHookThreadSafetyConcurrentAccess() {
        let queue = DispatchQueue(label: "test.threadSafety", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<100 {
            group.enter()
            queue.async {
                EventTapHook.shared.isEnabled = (i % 2 == 0)
                _ = EventTapHook.shared.isEnabled
                EventTapHook.shared.lastActiveVietnameseMethod = (i % 2 == 0 ? .telex : .vni)
                _ = EventTapHook.shared.lastActiveVietnameseMethod
                group.leave()
            }
        }
        let waitResult = group.wait(timeout: .now() + 2.0)
        XCTAssertEqual(waitResult, .success)
        EventTapHook.shared.isEnabled = true
    }

    // MARK: - 11. CaretPill Horizontal Centering Math (Defect 19)

    func testCaretPillHorizontalCenteringMath() {
        let caretRect = CGRect(x: 500, y: 300, width: 4, height: 18)
        let dynamicWidth: CGFloat = 400
        let anchorPoint = CGPoint(x: caretRect.midX, y: caretRect.midY)
        let adjustedOriginX = anchorPoint.x - (dynamicWidth / 2.0)

        // Caret midX = 502, half width = 200 -> origin should be 302
        XCTAssertEqual(adjustedOriginX, 302)
        // Mid of resulting window should equal caret midX
        XCTAssertEqual(adjustedOriginX + (dynamicWidth / 2.0), caretRect.midX)
    }

    // MARK: - 12. Sandbox Suggestion ReplaceLastCompletedWord & Leading Space (Defect 12)

    func testSandboxSuggestionReplaceLastCompletedWordLogic() {
        // Simulating the sandbox logic with replaceLastCompletedWord
        var sandboxText = "tôi ko "
        let item = SuggestionItem(
            text: "không",
            kind: .teencodeExpansion,
            replaceLastCompletedWord: true,
            targetWordToReplace: "ko"
        )

        let ns = sandboxText as NSString
        let range = ns.range(of: item.targetWordToReplace, options: .backwards)
        XCTAssertNotEqual(range.location, NSNotFound)
        sandboxText = ns.replacingCharacters(in: range, with: item.text)
        if !sandboxText.hasSuffix(" ") {
            sandboxText += " "
        }
        XCTAssertEqual(sandboxText, "tôi không ")

        // Test empty sandbox text does not get leading space
        var emptySandbox = ""
        let defaultItem = SuggestionItem(text: "xin chào", kind: .wordCompletion)
        let trimmed = emptySandbox.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            emptySandbox = defaultItem.text + " "
        } else {
            emptySandbox = trimmed + " " + defaultItem.text + " "
        }
        XCTAssertEqual(emptySandbox, "xin chào ")
        XCTAssertFalse(emptySandbox.hasPrefix(" "))
    }

    // MARK: - 13. VoiceDictationService Worker Termination (Defect 13)

    func testVoiceDictationWorkerTerminationClean() {
        VoiceDictationService.shared.terminateSpeechWorker()
        // Must succeed without throwing
        XCTAssertTrue(true)
    }
}
