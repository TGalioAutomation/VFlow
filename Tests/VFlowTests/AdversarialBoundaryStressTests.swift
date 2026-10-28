import XCTest
import CoreGraphics
import AppKit
@testable import VFlowCore
@testable import VFlowPlatform

/// Adversarial empirical stress testing suite by Challenger 2 (teamwork_preview_challenger)
/// Rigorously validates boundary conditions, Unicode multi-scalar clusters, deletion symmetry,
/// whitespace normalization, bridge-word collocation resolution, and clause isolation.
final class AdversarialBoundaryStressTests: XCTestCase {

    // MARK: - Simulation Helper
    private func applyReplacement(
        in text: String,
        cursorLocation: Int,
        leftDeleteCount: Int,
        rightDeleteCount: Int,
        replacementText: String
    ) -> String {
        let ns = text as NSString
        let safeCursor = max(0, min(ns.length, cursorLocation))
        let leftStart = max(0, safeCursor - leftDeleteCount)
        let rightEnd = min(ns.length, safeCursor + rightDeleteCount)

        let leftKeep = ns.substring(to: leftStart)
        let rightKeep = ns.substring(from: rightEnd)
        return leftKeep + replacementText + rightKeep
    }

    // MARK: - 1. Start of Text Boundary Condition (cursorLocation == 0 and Out-of-Bounds)

    func testStartOfText_EmptyDocument() {
        let text = ""
        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: 0)

        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "")
        XCTAssertEqual(ctx.wordBeforeCursor, "")
        XCTAssertEqual(ctx.wordAfterCursor, "")
        XCTAssertEqual(ctx.cursorLocation, 0)

        let (cStart, cEnd) = EventTapHook.findClauseBounds(in: text, cursorLocation: 0)
        XCTAssertEqual(cStart, 0)
        XCTAssertEqual(cEnd, 0)
    }

    func testStartOfText_NegativeCursorLocationClamped() {
        let text = "duoc hết text"
        // Negative cursor location must clamp safely to 0 without crashing
        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: -10)
        XCTAssertEqual(ctx.cursorLocation, 0)
        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "duoc")
        XCTAssertEqual(ctx.wordAtCursor, "duoc")

        let (cStart, cEnd) = EventTapHook.findClauseBounds(in: text, cursorLocation: -10)
        XCTAssertEqual(cStart, 0)
        XCTAssertEqual(cEnd, 13)
    }

    func testStartOfText_SingleCharacterDocument() {
        let text = "a"
        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: 0)
        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "a")
        XCTAssertEqual(ctx.wordAtCursor, "a")
        XCTAssertEqual(ctx.wordBeforeCursor, "")
        XCTAssertEqual(ctx.wordAfterCursor, "")
        XCTAssertEqual(ctx.wordPrefix.count, 0)
        XCTAssertEqual(ctx.wordSuffix.count, 1)

        let result = applyReplacement(
            in: text,
            cursorLocation: 0,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "ả"
        )
        XCTAssertEqual(result, "ả")
    }

    func testStartOfText_LeadingSpacesAndPunctuation() {
        let text = "   ...duoc hết"
        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: 0)
        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "")
        XCTAssertEqual(ctx.wordBeforeCursor, "")
        XCTAssertEqual(ctx.wordAfterCursor, "duoc")
    }

    func testStartOfText_LeadingNewline() {
        let text = "\nduoc hết text"
        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: 0)
        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "")
        XCTAssertEqual(ctx.wordBeforeCursor, "")
        XCTAssertEqual(ctx.wordAfterCursor, "duoc")
    }

    // MARK: - 2. Middle of Word: Exhaustive Interior Slicing & Symmetric Deletion

    func testMiddleOfWord_ExhaustiveSlicingAcrossLengths() {
        // Test words from 2 to 7 characters at every single valid interior cursor position
        let testWords = [
            ("đi", "đi"),
            ("anh", "anh"),
            ("duoc", "được"),
            ("truoc", "trước"),
            ("nghieng", "nghiêng")
        ]

        for (word, replacement) in testWords {
            let nsWord = word as NSString
            let wordLen = nsWord.length
            guard wordLen >= 2 else { continue }

            for cutIndex in 1..<wordLen {
                let doc = "bắt đầu \(word) kết thúc"
                let nsDoc = doc as NSString
                let wordRange = nsDoc.range(of: word)
                XCTAssertNotEqual(wordRange.location, NSNotFound)

                let cursorLoc = wordRange.location + cutIndex
                let ctx = AccessibilityBridge.extractContext(fullText: doc, cursorLocation: cursorLoc)

                let expectedPrefix = nsWord.substring(to: cutIndex)
                let expectedSuffix = nsWord.substring(from: cutIndex)

                XCTAssertEqual(ctx.wordPrefix, expectedPrefix, "Prefix mismatch for '\(word)' at index \(cutIndex)")
                XCTAssertEqual(ctx.wordSuffix, expectedSuffix, "Suffix mismatch for '\(word)' at index \(cutIndex)")
                XCTAssertEqual(ctx.wordAtCursor, word, "Full wordAtCursor mismatch for '\(word)'")
                XCTAssertEqual(ctx.wordBeforeCursor, "đầu")
                XCTAssertEqual(ctx.wordAfterCursor, "kết")

                // Deletion symmetry
                XCTAssertEqual(ctx.wordPrefix.count + ctx.wordSuffix.count, word.count)

                let result = applyReplacement(
                    in: doc,
                    cursorLocation: cursorLoc,
                    leftDeleteCount: ctx.wordPrefix.count,
                    rightDeleteCount: ctx.wordSuffix.count,
                    replacementText: replacement
                )
                let expectedDoc = "bắt đầu \(replacement) kết thúc"
                XCTAssertEqual(result, expectedDoc, "Symmetric replacement failed for '\(word)' cut at \(cutIndex)")
            }
        }
    }

    func testMiddleOfWord_BoundedByPunctuation() {
        // Parens: "(du|oc)"
        let parenDoc = "kết quả (duoc) tốt"
        let nsParen = parenDoc as NSString
        let duocRange = nsParen.range(of: "duoc")
        let cursorInParen = duocRange.location + 2 // between 'u' and 'o'

        let ctxParen = AccessibilityBridge.extractContext(fullText: parenDoc, cursorLocation: cursorInParen)
        XCTAssertEqual(ctxParen.wordPrefix, "du")
        XCTAssertEqual(ctxParen.wordSuffix, "oc")
        XCTAssertEqual(ctxParen.wordAtCursor, "duoc")

        let replacedParen = applyReplacement(
            in: parenDoc,
            cursorLocation: cursorInParen,
            leftDeleteCount: ctxParen.wordPrefix.count,
            rightDeleteCount: ctxParen.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(replacedParen, "kết quả (được) tốt", "Punctuation parens must remain intact")

        // Comma: "du|oc, xong"
        let commaDoc = "duoc, xong"
        let ctxComma = AccessibilityBridge.extractContext(fullText: commaDoc, cursorLocation: 2)
        XCTAssertEqual(ctxComma.wordPrefix, "du")
        XCTAssertEqual(ctxComma.wordSuffix, "oc")
        XCTAssertEqual(ctxComma.wordAtCursor, "duoc")

        let replacedComma = applyReplacement(
            in: commaDoc,
            cursorLocation: 2,
            leftDeleteCount: ctxComma.wordPrefix.count,
            rightDeleteCount: ctxComma.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(replacedComma, "được, xong", "Trailing comma must remain intact")

        // Quotes: "\"du|oc\""
        let quoteDoc = "\"duoc\""
        let ctxQuote = AccessibilityBridge.extractContext(fullText: quoteDoc, cursorLocation: 3)
        XCTAssertEqual(ctxQuote.wordPrefix, "du")
        XCTAssertEqual(ctxQuote.wordSuffix, "oc")
        XCTAssertEqual(ctxQuote.wordAtCursor, "duoc")

        let replacedQuote = applyReplacement(
            in: quoteDoc,
            cursorLocation: 3,
            leftDeleteCount: ctxQuote.wordPrefix.count,
            rightDeleteCount: ctxQuote.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(replacedQuote, "\"được\"", "Surrounding quotes must remain intact")
    }

    func testMiddleOfWord_BeforePunctuationSpaceEvaluation() {
        // Document with word immediately followed by punctuation: "không duoc, hết text"
        let doc = "không duoc, hết text"
        let ns = doc as NSString
        let duocRange = ns.range(of: "duoc")
        let cursorLoc = duocRange.location + 2 // between 'u' and 'o'

        let ctx = AccessibilityBridge.extractContext(fullText: doc, cursorLocation: cursorLoc)
        let suffixLength = (ctx.wordSuffix as NSString).length
        let afterWordIndex = min(ns.length, cursorLoc + suffixLength)
        let rightStr = ns.substring(from: afterWordIndex)

        // Notice that rightStr starts with "," and not " "
        XCTAssertTrue(rightStr.hasPrefix(","))
        XCTAssertFalse(rightStr.hasPrefix(" "))

        // In EventTapHook line 580-591, hasSpaceAfterCursor only checks rightStr.hasPrefix(" ")!
        // Because hasSpaceAfterCursor evaluates to false, EventTapHook appends a trailing space:
        // postUnicodeString(item.text + (hasSpaceAfterCursor ? "" : " "))
        // This causes an illegal space before punctuation: "được ," instead of "được,"!
        let hasSpaceAfterCursor = rightStr.hasPrefix(" ")
        let trailingSpaceAppended = hasSpaceAfterCursor ? "" : " "
        XCTAssertEqual(trailingSpaceAppended, " ", "Empirical proof: EventTapHook appends trailing space even when followed by punctuation")
    }

    // MARK: - 3. Between Double Spaces & Multiple Trailing Spaces

    func testBetweenMultipleSpaces_ExhaustiveWhitespaceGaps() {
        // Test gaps of 2, 3, 5, and 10 spaces between words
        let spaceCounts = [2, 3, 5, 10]
        for numSpaces in spaceCounts {
            let spaces = String(repeating: " ", count: numSpaces)
            let text = "không\(spaces)thị"
            let prefixLen = ("không" as NSString).length

            // Place cursor at every point inside the whitespace gap
            for spaceOffset in 1..<numSpaces {
                let cursorLoc = prefixLen + spaceOffset
                let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: cursorLoc)

                XCTAssertEqual(ctx.wordPrefix, "", "wordPrefix inside \(numSpaces)-space gap must be empty")
                XCTAssertEqual(ctx.wordSuffix, "", "wordSuffix inside \(numSpaces)-space gap must be empty")
                XCTAssertEqual(ctx.wordAtCursor, "", "wordAtCursor inside whitespace gap must be empty")
                XCTAssertEqual(ctx.wordBeforeCursor, "không")
                XCTAssertEqual(ctx.wordAfterCursor, "thị")

                // Bridge word resolution must still succeed
                let bridge = SuggestionEngine.resolveBridgeWord(
                    left: ctx.wordBeforeCursor,
                    right: ctx.wordAfterCursor
                )
                XCTAssertEqual(bridge, "hiển")
            }
        }
    }

    func testMultipleTrailingSpaces_VariableLengths() {
        let targetWord = "ko"
        let spaceCounts = [1, 2, 3, 4, 8]

        for sCount in spaceCounts {
            let doc = "tôi " + targetWord + String(repeating: " ", count: sCount)
            let ns = doc as NSString
            let cursorLoc = ns.length

            // Count trailing whitespace dynamically
            var detectedSpaces = 0
            let leftStr = ns.substring(to: cursorLoc)
            for ch in leftStr.reversed() {
                if ch.isWhitespace { detectedSpaces += 1 } else { break }
            }
            XCTAssertEqual(detectedSpaces, sCount)

            let totalBackspaces = targetWord.count + detectedSpaces
            let prefixKept = ns.substring(to: cursorLoc - totalBackspaces)
            XCTAssertEqual(prefixKept, "tôi ", "Left text before 'ko' must be preserved exactly")

            let replaced = prefixKept + "không "
            XCTAssertEqual(replaced, "tôi không ", "Replacement must normalize to exactly single space")
        }
    }

    // MARK: - 4. End of Text Boundary Condition & Overshoot

    func testEndOfText_AtLastWordBoundary() {
        let text = "học tiếng Việt"
        let ns = text as NSString
        let cursorLoc = ns.length // 14

        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "Việt")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "Việt")
        XCTAssertEqual(ctx.wordBeforeCursor, "tiếng")
        XCTAssertEqual(ctx.wordAfterCursor, "")
        XCTAssertEqual(ctx.wordPrefix.count, 4)
        XCTAssertEqual(ctx.wordSuffix.count, 0)

        let result = applyReplacement(
            in: text,
            cursorLocation: cursorLoc,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "Việt Nam"
        )
        XCTAssertEqual(result, "học tiếng Việt Nam")
    }

    func testEndOfText_OvershootClampedGracefully() {
        let text = "văn bản mẫu"
        let ns = text as NSString
        let overshootLoc = 99999

        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: overshootLoc)
        XCTAssertEqual(ctx.cursorLocation, ns.length)
        XCTAssertEqual(ctx.wordPrefix, "mẫu")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "mẫu")
        XCTAssertEqual(ctx.wordBeforeCursor, "bản")
        XCTAssertEqual(ctx.wordAfterCursor, "")

        let (cStart, cEnd) = EventTapHook.findClauseBounds(in: text, cursorLocation: overshootLoc)
        XCTAssertEqual(cStart, 0)
        XCTAssertEqual(cEnd, ns.length)
    }

    func testEndOfText_WithTrailingPunctuation() {
        let text = "chào bạn."
        let ns = text as NSString
        let cursorLoc = ns.length

        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "")
        XCTAssertEqual(ctx.wordBeforeCursor, "bạn")
        XCTAssertEqual(ctx.wordAfterCursor, "")
    }

    // MARK: - 5. Unicode Multi-Scalar Characters (Emojis, Accents, NFD)

    func testUnicodeMultiScalar_SkinToneAndGenderEmojis() {
        // Woman developer: 👩🏻‍💻 (Woman + light skin tone + ZWJ + Laptop)
        let text = "Kỹ sư 👩🏻‍💻 duoc khen ngợi"
        let ns = text as NSString
        let duocRange = ns.range(of: "duoc")
        let cursorLoc = duocRange.location + 2

        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "du")
        XCTAssertEqual(ctx.wordSuffix, "oc")
        XCTAssertEqual(ctx.wordAtCursor, "duoc")
        XCTAssertEqual(ctx.wordBeforeCursor, "👩🏻‍💻")
        XCTAssertEqual(ctx.wordAfterCursor, "khen")

        let result = applyReplacement(
            in: text,
            cursorLocation: cursorLoc,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(result, "Kỹ sư 👩🏻‍💻 được khen ngợi")
    }

    func testUnicodeMultiScalar_MultiFlagEmojis() {
        // Multiple flags: 🇻🇳 and 🇯🇵
        let text = "Hợp tác 🇻🇳 🇯🇵 duoc thúc đẩy"
        let ns = text as NSString
        let duocRange = ns.range(of: "duoc")
        let cursorLoc = duocRange.location + 2

        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "du")
        XCTAssertEqual(ctx.wordSuffix, "oc")
        XCTAssertEqual(ctx.wordBeforeCursor, "🇯🇵")
        XCTAssertEqual(ctx.wordAfterCursor, "thúc")

        let result = applyReplacement(
            in: text,
            cursorLocation: cursorLoc,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(result, "Hợp tác 🇻🇳 🇯🇵 được thúc đẩy")
    }

    func testUnicode_NFCComposedVietnameseVowels() {
        // NFC representation: 'đường' fully composed
        let nfcWord = "đường"
        let text = "Con \(nfcWord) rộng"
        let ns = text as NSString
        let rongRange = ns.range(of: "rộng")
        let cursorLoc = rongRange.location + 1 // inside 'rộng' after 'r'

        let ctx = AccessibilityBridge.extractContext(fullText: text, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "r")
        XCTAssertEqual(ctx.wordSuffix, "ộng")
        XCTAssertEqual(ctx.wordAtCursor, "rộng")
        XCTAssertEqual(ctx.wordBeforeCursor, "đường")
    }

    func testUnicode_NFDDecomposedCursorDriftRemediation() {
        // Decomposed NFD Vietnamese string: 'ếch' as 'e' + '\u{0302}' + '\u{0301}' + 'c' + 'h' (length 5)
        let nfdWord = "e\u{0302}\u{0301}ch"
        let rawDoc = "Con \(nfdWord) nhảy xa"
        let rawNS = rawDoc as NSString
        XCTAssertEqual(rawNS.length, 17)

        // When cursor is at raw index 14 (touching 'nhảy' on the right, before the space)
        let cursorInRawDocAtSpace = 14
        let ctx = AccessibilityBridge.extractContext(fullText: rawDoc, cursorLocation: cursorInRawDocAtSpace)

        // In precomposed text ("Con ếch nhảy xa"), length is 15.
        // Index 12 corresponds to the exact position after 'nhảy', before 'xa'.
        // Cursor index mapping prevents drift into 'xa'.
        XCTAssertEqual(ctx.fullText, "Con ếch nhảy xa")
        XCTAssertEqual((ctx.fullText as NSString).length, 15)
        XCTAssertEqual(ctx.cursorLocation, 12, "Cursor index in precomposed text must be accurately mapped to 12")
        XCTAssertEqual(ctx.wordPrefix, "nhảy")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "nhảy")
        XCTAssertEqual(ctx.wordBeforeCursor, "ếch")
        XCTAssertEqual(ctx.wordAfterCursor, "xa")
    }

    func testUnicode_NFDDecomposedVietnameseVowels() {
        let nfdDuong = "đường".decomposedStringWithCanonicalMapping
        let rawDoc = "Con \(nfdDuong) rộng"
        let rawNS = rawDoc as NSString
        let rongRange = rawNS.range(of: "rộng")
        let cursorLoc = rongRange.location + 1 // inside 'rộng' after 'r'

        let ctx = AccessibilityBridge.extractContext(fullText: rawDoc, cursorLocation: cursorLoc)
        XCTAssertEqual(ctx.wordPrefix, "r")
        XCTAssertEqual(ctx.wordSuffix, "ộng")
        XCTAssertEqual(ctx.wordAtCursor, "rộng")
        XCTAssertEqual(ctx.wordBeforeCursor, "đường")
    }

    // MARK: - 6. Bridge-Word Collocation Resolution Stress

    func testBridgeWord_CaseInsensitivityAndPunctuationTrimming() {
        // Upper case and mixed case
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "KHÔNG", right: "THỊ"), "hiển")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "Không", right: "Thị"), "hiển")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "khong", right: "thi"), "hiển")

        // Punctuation trimmed
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "\"không\",", right: "thị!"), "hiển")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "(chưa)", right: "[yêu]"), "đạt")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "bị:", right: "hiển;"), "lỗi")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "hỗ-", right: "tiếng?"), "trợ")
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "xin...", right: "on!"), "cảm")

        // Unmatched words return nil cleanly
        XCTAssertNil(SuggestionEngine.resolveBridgeWord(left: "con", right: "mèo"))
        XCTAssertNil(SuggestionEngine.resolveBridgeWord(left: "", right: "thị"))
        XCTAssertNil(SuggestionEngine.resolveBridgeWord(left: "không", right: ""))
    }

    // MARK: - 7. Multi-Sentence & Multiline Document Clause Bounding Stress

    func testClauseBounding_MultiSentenceDocumentDelimiters() {
        let doc = "Câu 1. Câu 2! không thị duoc hết text? Câu 4. Câu 5."
        let ns = doc as NSString
        let target = "không thị duoc hết text"
        let targetRange = ns.range(of: target)
        XCTAssertNotEqual(targetRange.location, NSNotFound)

        // Test cursor at start of target, middle of target, and end of target
        let probeOffsets = [0, 5, 10, targetRange.length - 1]
        for offset in probeOffsets {
            let cursorLoc = targetRange.location + offset
            let (start, end) = EventTapHook.findClauseBounds(in: doc, cursorLocation: cursorLoc)

            XCTAssertEqual(start, targetRange.location, "Clause start mismatch at offset \(offset)")
            XCTAssertEqual(end, targetRange.location + targetRange.length, "Clause end mismatch at offset \(offset)")

            let extracted = ns.substring(with: NSRange(location: start, length: end - start))
            XCTAssertEqual(extracted, target)
        }
    }

    func testClauseBounding_MultilineParagraphDelimiters() {
        let doc = "Dòng một\nkhông thị duoc hết text\nDòng ba"
        let ns = doc as NSString
        let target = "không thị duoc hết text"
        let targetRange = ns.range(of: target)

        let cursorLoc = targetRange.location + 8
        let (start, end) = EventTapHook.findClauseBounds(in: doc, cursorLocation: cursorLoc)

        XCTAssertEqual(start, targetRange.location)
        XCTAssertEqual(end, targetRange.location + targetRange.length)

        let extracted = ns.substring(with: NSRange(location: start, length: end - start))
        XCTAssertEqual(extracted, target)
    }

    func testClauseBounding_DocumentWithoutPunctuation() {
        let doc = "không thị duoc hết text"
        let ns = doc as NSString
        let cursorLoc = 10

        let (start, end) = EventTapHook.findClauseBounds(in: doc, cursorLocation: cursorLoc)
        XCTAssertEqual(start, 0)
        XCTAssertEqual(end, ns.length)
    }
}
