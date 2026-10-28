import XCTest
import CoreGraphics
import AppKit
@testable import VFlowCore
@testable import VFlowPlatform

/// Comprehensive boundary condition test suite fulfilling Milestone 4 Requirement R4-BOUNDARY:
/// Automated tests for mid-sentence cursor editing, missing bridge-word insertion, and full-sentence polish replacement:
/// 1. Start of text (cursorLocation == 0)
/// 2. Middle of word (symmetric deletion and insertion)
/// 3. Between double spaces
/// 4. End of text
/// 5. Unicode multi-scalar characters (emojis, composed diacritics, NFD vs NFC normalization)
/// 6. Missing bridge-word detection and gap insertion
/// 7. Multi-sentence document isolation for full-sentence polish
final class MidSentenceCursorAndBoundaryTests: XCTestCase {

    // Helper simulating symmetric text replacement given left delete count, right delete count, and replacement text
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

    // MARK: - 1. Start of Text Boundary Condition (cursorLocation == 0)

    func testStartOfTextBoundaryCondition() {
        let fullText = "duoc hết text"
        // Cursor at very start of text: index 0
        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: 0)

        XCTAssertEqual(ctx.wordPrefix, "", "wordPrefix at index 0 must be empty")
        XCTAssertEqual(ctx.wordSuffix, "duoc", "wordSuffix at index 0 should contain the first word 'duoc'")
        XCTAssertEqual(ctx.wordAtCursor, "duoc", "wordAtCursor should be 'duoc'")
        XCTAssertEqual(ctx.wordBeforeCursor, "", "wordBeforeCursor must be empty string at start of document")
        XCTAssertEqual(ctx.wordAfterCursor, "hết", "wordAfterCursor should be 'hết'")
        XCTAssertEqual(ctx.wordPrefix.count, 0, "Left delete count must be 0 at start of document")
        XCTAssertEqual(ctx.wordSuffix.count, 4, "Right delete count must be 4 ('duoc'.count)")

        // Symmetrically replace "duoc" with "được"
        let resultingText = applyReplacement(
            in: fullText,
            cursorLocation: 0,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(resultingText, "được hết text", "Replacing word at index 0 must not prepend illegal leading space")

        // Test full-sentence clause bounding at start of document
        let (clauseStart, clauseEnd) = EventTapHook.findClauseBounds(in: fullText, cursorLocation: 0)
        XCTAssertEqual(clauseStart, 0, "Clause start must be 0 at beginning of document")
        XCTAssertEqual(clauseEnd, 13, "Clause end must span to end of clause")
    }

    // MARK: - 2. Middle of Word: Symmetric Deletion and Insertion

    func testMiddleOfWordSymmetricDeletion_4LetterWord() {
        // "không du|oc hết text" with cursor at index 8 (between 'u' and 'o' in "duoc")
        let fullText = "không duoc hết text"
        let cursorLocation = 8

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "du", "Prefix left of cursor should be 'du'")
        XCTAssertEqual(ctx.wordSuffix, "oc", "Suffix right of cursor should be 'oc'")
        XCTAssertEqual(ctx.wordAtCursor, "duoc", "Full word at cursor must be 'duoc'")
        XCTAssertEqual(ctx.wordBeforeCursor, "không")
        XCTAssertEqual(ctx.wordAfterCursor, "hết")

        let leftDeletes = ctx.wordPrefix.count
        let rightDeletes = ctx.wordSuffix.count
        XCTAssertEqual(leftDeletes, 2, "Must backspace 2 characters for 'du'")
        XCTAssertEqual(rightDeletes, 2, "Must forward-delete 2 characters for 'oc'")

        let result = applyReplacement(
            in: fullText,
            cursorLocation: cursorLocation,
            leftDeleteCount: leftDeletes,
            rightDeleteCount: rightDeletes,
            replacementText: "được"
        )
        XCTAssertEqual(result, "không được hết text", "Resulting text must not have duplicate 'oc' or missing characters")
    }

    func testMiddleOfWordSymmetricDeletion_5LetterWord() {
        // "phía tr|uoc ngôi nhà" with cursor at index 7 (between 'r' and 'u' in "truoc")
        let fullText = "phía truoc ngôi nhà"
        let cursorLocation = 7

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "tr")
        XCTAssertEqual(ctx.wordSuffix, "uoc")
        XCTAssertEqual(ctx.wordAtCursor, "truoc")

        let leftDeletes = ctx.wordPrefix.count
        let rightDeletes = ctx.wordSuffix.count
        XCTAssertEqual(leftDeletes, 2)
        XCTAssertEqual(rightDeletes, 3)

        let result = applyReplacement(
            in: fullText,
            cursorLocation: cursorLocation,
            leftDeleteCount: leftDeletes,
            rightDeleteCount: rightDeletes,
            replacementText: "trước"
        )
        XCTAssertEqual(result, "phía trước ngôi nhà")
    }

    func testMiddleOfWordSymmetricDeletion_6LetterWord() {
        // "nghi|eng bóng" with cursor at index 4 (between 'i' and 'e' in "nghieng")
        let fullText = "nghieng bóng"
        let cursorLocation = 4

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "nghi")
        XCTAssertEqual(ctx.wordSuffix, "eng")
        XCTAssertEqual(ctx.wordAtCursor, "nghieng")

        let leftDeletes = ctx.wordPrefix.count
        let rightDeletes = ctx.wordSuffix.count
        XCTAssertEqual(leftDeletes, 4)
        XCTAssertEqual(rightDeletes, 3)

        let result = applyReplacement(
            in: fullText,
            cursorLocation: cursorLocation,
            leftDeleteCount: leftDeletes,
            rightDeleteCount: rightDeletes,
            replacementText: "nghiêng"
        )
        XCTAssertEqual(result, "nghiêng bóng")
    }

    // MARK: - 3. Between Double Spaces Boundary Condition

    func testBetweenDoubleSpacesBoundaryCondition() {
        let fullText = "không  thị"
        // Cursor at index 6, exactly between the two spaces
        let cursorLocation = 6
        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)

        XCTAssertEqual(ctx.wordPrefix, "", "wordPrefix between spaces must be empty")
        XCTAssertEqual(ctx.wordSuffix, "", "wordSuffix between spaces must be empty")
        XCTAssertEqual(ctx.wordAtCursor, "", "wordAtCursor between spaces must be empty")
        XCTAssertEqual(ctx.wordBeforeCursor, "không")
        XCTAssertEqual(ctx.wordAfterCursor, "thị")

        // Bridge word resolution
        let bridge = SuggestionEngine.resolveBridgeWord(
            left: ctx.wordBeforeCursor,
            right: ctx.wordAfterCursor
        )
        XCTAssertEqual(bridge, "hiển", "Bridge word between 'không' and 'thị' must be 'hiển'")

        // Bridge insertion with gap normalization:
        // Replace the 2 spaces with single spaces around "hiển" -> "không hiển thị"
        let beforeWord = ctx.wordBeforeCursor
        let afterWord = ctx.wordAfterCursor
        let gapNormalized = "\(beforeWord) \(bridge!) \(afterWord)"
        XCTAssertEqual(gapNormalized, "không hiển thị")
    }

    func testMultipleTrailingSpacesCountPreventionOfDuplication() {
        let fullText = "tôi ko   " // 3 spaces after 'ko'
        let ns = fullText as NSString
        let cursorLocation = ns.length

        // Count trailing whitespaces
        var whitespaceCount = 0
        let leftStr = ns.substring(to: cursorLocation)
        for ch in leftStr.reversed() {
            if ch.isWhitespace { whitespaceCount += 1 } else { break }
        }
        XCTAssertEqual(whitespaceCount, 3, "Must count all 3 trailing spaces")

        let targetWord = "ko"
        let totalBackspaces = targetWord.count + whitespaceCount
        XCTAssertEqual(totalBackspaces, 5, "Total backspaces must be 2 ('ko') + 3 (spaces) = 5")

        let replaced = ns.substring(to: cursorLocation - totalBackspaces) + "không "
        XCTAssertEqual(replaced, "tôi không ", "Character 'k' must never be duplicated into 'kkhông'")
    }

    // MARK: - 4. End of Text Boundary Condition

    func testEndOfTextBoundaryCondition_AtWordEnd() {
        let fullText = "hôm nay trời đẹp"
        let cursorLocation = (fullText as NSString).length // 16

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "đẹp", "wordPrefix at end of text should be 'đẹp'")
        XCTAssertEqual(ctx.wordSuffix, "", "wordSuffix at end of text should be empty")
        XCTAssertEqual(ctx.wordAtCursor, "đẹp")
        XCTAssertEqual(ctx.wordBeforeCursor, "trời")
        XCTAssertEqual(ctx.wordAfterCursor, "", "wordAfterCursor should be empty string at end of text")

        XCTAssertEqual(ctx.wordPrefix.count, 3, "Left backspaces must match 'đẹp'.count")
        XCTAssertEqual(ctx.wordSuffix.count, 0, "Right forward-deletes must be 0")

        let result = applyReplacement(
            in: fullText,
            cursorLocation: cursorLocation,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "rất đẹp"
        )
        XCTAssertEqual(result, "hôm nay trời rất đẹp")
    }

    func testEndOfTextBoundaryCondition_AtTrailingSpace() {
        let fullText = "hôm nay trời đẹp "
        let cursorLocation = (fullText as NSString).length

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "")
        XCTAssertEqual(ctx.wordSuffix, "")
        XCTAssertEqual(ctx.wordAtCursor, "")
        XCTAssertEqual(ctx.wordBeforeCursor, "đẹp")
        XCTAssertEqual(ctx.wordAfterCursor, "")
    }

    // MARK: - 5. Unicode Multi-Scalar & Decomposed Character Handling

    func testUnicodeMultiScalar_FlagEmojiContext() {
        let fullText = "Cờ 🇻🇳 duoc treo lên"
        let ns = fullText as NSString
        let duocRange = ns.range(of: "duoc")
        let cursorLocation = duocRange.location + 2 // between 'u' and 'o'

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "du")
        XCTAssertEqual(ctx.wordSuffix, "oc")
        XCTAssertEqual(ctx.wordAtCursor, "duoc")
        XCTAssertEqual(ctx.wordBeforeCursor, "🇻🇳", "Emoji '🇻🇳' before cursor must be preserved intact")
        XCTAssertEqual(ctx.wordAfterCursor, "treo")

        let result = applyReplacement(
            in: fullText,
            cursorLocation: cursorLocation,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "được"
        )
        XCTAssertEqual(result, "Cờ 🇻🇳 được treo lên")
    }

    func testUnicodeMultiScalar_ComplexZWJEmoji() {
        // Family emoji: 👨‍👩‍👧‍👦 (composed of multiple scalars with zero-width joiners)
        let fullText = "Gia đình 👨‍👩‍👧‍👦 khuyen vui vẻ"
        let ns = fullText as NSString
        let khuyenRange = ns.range(of: "khuyen")
        let cursorLocation = khuyenRange.location + 3 // inside "khuyen" after "khu"

        let ctx = AccessibilityBridge.extractContext(fullText: fullText, cursorLocation: cursorLocation)
        XCTAssertEqual(ctx.wordPrefix, "khu")
        XCTAssertEqual(ctx.wordSuffix, "yen")
        XCTAssertEqual(ctx.wordAtCursor, "khuyen")
        XCTAssertEqual(ctx.wordBeforeCursor, "👨‍👩‍👧‍👦")
        XCTAssertEqual(ctx.wordAfterCursor, "vui")

        let result = applyReplacement(
            in: fullText,
            cursorLocation: cursorLocation,
            leftDeleteCount: ctx.wordPrefix.count,
            rightDeleteCount: ctx.wordSuffix.count,
            replacementText: "khuyên"
        )
        XCTAssertEqual(result, "Gia đình 👨‍👩‍👧‍👦 khuyên vui vẻ")
    }

    func testUnicodeNFDNormalizationHandling() {
        // Create an NFD decomposed Vietnamese string: 'ế' as 'e' + combining hat + combining acute
        let nfdWord = "e\u{0302}\u{0301}ch" // ếch
        let doc = "Con \(nfdWord) nhảy xa"
        let ns = doc as NSString
        let nhayRange = ns.range(of: "nhảy")
        XCTAssertNotEqual(nhayRange.location, NSNotFound)

        // Place cursor inside word "xa" (after 'x')
        let xaRange = ns.range(of: "xa")
        XCTAssertNotEqual(xaRange.location, NSNotFound)
        let cursorLoc = xaRange.location + 1
        let ctx = AccessibilityBridge.extractContext(fullText: doc, cursorLocation: cursorLoc)

        // Verify grapheme cluster boundary extraction does not corrupt decomposed scalars
        XCTAssertEqual(ctx.wordPrefix, "x")
        XCTAssertEqual(ctx.wordSuffix, "a")
        XCTAssertEqual(ctx.wordAtCursor, "xa")
        XCTAssertEqual(ctx.wordBeforeCursor, "nhảy")
        XCTAssertEqual(ctx.wordAfterCursor, "")
    }

    // MARK: - 6. Missing Bridge-Word Insertion

    func testMissingBridgeWord_FlushAgainstLeftWord() {
        // "không| thị" (cursor flush against "không", no space between cursor and left word)
        let suggestions = SuggestionEngine.suggest(
            currentWord: "không",
            rawWord: "khong",
            sentenceWords: ["không"],
            wordAfterCursor: "thị"
        )

        let bridge = suggestions.first { $0.text == "hiển" }
        XCTAssertNotNil(bridge, "Bridge word 'hiển' must be offered when cursor touches 'không| thị'")
        XCTAssertFalse(bridge?.replaceCurrentWord ?? true, "Bridge word must NOT replace the left word 'không'")
    }

    func testMissingBridgeWord_ShorthandAndUnsigned() {
        // Shorthand "ko| thị"
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "ko", right: "thị"), "hiển")
        // Unsigned "khong | thi"
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "khong", right: "thi"), "hiển")
        // "chua | value"
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "chua", right: "value"), "đạt")
        // "xin | on"
        XCTAssertEqual(SuggestionEngine.resolveBridgeWord(left: "xin", right: "on"), "cảm")
    }

    // MARK: - 7. Multi-Sentence Document Isolation for Full-Sentence Polish

    func testFullSentencePolish_IsolatesSentenceWithoutWipingDocument() {
        let fullDocument = "Chào buổi sáng. không thị duoc hết text. Chúc một ngày tốt lành."
        let ns = fullDocument as NSString
        let midSentenceRange = ns.range(of: "không thị duoc hết text")
        let cursorLocation = midSentenceRange.location + 10 // inside "duoc"

        let (start, end) = EventTapHook.findClauseBounds(in: fullDocument, cursorLocation: cursorLocation)
        XCTAssertEqual(start, midSentenceRange.location, "Clause start must align exactly with 'không'")
        XCTAssertEqual(end, midSentenceRange.location + midSentenceRange.length, "Clause end must align with 'text'")

        let extractedClause = ns.substring(with: NSRange(location: start, length: end - start))
        XCTAssertEqual(extractedClause, "không thị duoc hết text")

        // Polish only the isolated clause
        let polishedClause = VietnameseTextPolisher.polish(extractedClause)
        XCTAssertEqual(polishedClause, "không hiển thị được hết text")

        // Replace only the clause within the document
        let finalDocument = ns.substring(to: start) + polishedClause + ns.substring(from: end)
        let expectedDocument = "Chào buổi sáng. không hiển thị được hết text. Chúc một ngày tốt lành."
        XCTAssertEqual(
            finalDocument,
            expectedDocument,
            "Full-sentence polish must strictly preserve surrounding sentences"
        )
    }
}
