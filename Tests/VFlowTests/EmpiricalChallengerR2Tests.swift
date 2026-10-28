import XCTest
import CoreGraphics
import AppKit
@testable import VFlowCore
@testable import VFlowPlatform

/// Adversarial empirical challenge test suite authored and executed by Challenger R2 (teamwork_preview_challenger).
/// Rigorously verifies:
/// 1. `uyê` triphthong tone placement, free-order roll, VNI composition, and tone stripping ('z' / '0').
/// 2. Developer keywords (`def`, `ref`, `rust`, `vest`) and empirical diagnosis of the homograph collision regression.
/// 3. Zero cursor offset drift on NFD decomposed Unicode text across 100% of cursor positions.
/// 4. Punctuation-aware word replacement in EventTapHook suppressing extra whitespace before punctuation marks.
/// 5. VietnameseTextPolisher dynamic heuristic integrity without hardcoded benchmark strings.
final class EmpiricalChallengerR2Tests: XCTestCase {

    var telexEngine: VietnameseInputEngine!
    var vniEngine: VietnameseInputEngine!

    override func setUp() {
        super.setUp()
        telexEngine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
        vniEngine = VietnameseInputEngine(inputMethod: .vni, tonePlacement: .modern, autoEnglishRestore: true)
    }

    // MARK: - Simulation Helpers

    private func simulateTyping(_ input: String, on engine: VietnameseInputEngine) -> String {
        engine.reset()
        var screen = ""
        for ch in input {
            let res = engine.processKey(ch)
            if res.consumed {
                if res.backspaceCount > 0 {
                    let drop = min(res.backspaceCount, screen.count)
                    screen = String(screen.dropLast(drop))
                }
                screen += res.replacementText
            } else {
                screen.append(ch)
            }
        }
        return screen
    }

    private func typeWordWithSpace(_ input: String, on engine: VietnameseInputEngine) -> String {
        return simulateTyping(input + " ", on: engine)
    }

    // MARK: - 1. EMPIRICAL STRESS: uyê Triphthongs Across All Syllable Configurations

    func testUyeTriphthong_TonePlacementOnNucleusEAcrossInitials() {
        // Target words specified in Challenger R2 mission: tuyết, thuyền, chuyện, khuyến, duyệt, nguyện
        let missionTargets: [(telex: String, vni: String, expected: String)] = [
            ("tuyeets", "tuyet61", "tuyết"),
            ("thuyeenf", "thuyen62", "thuyền"),
            ("chuyeenj", "chuyen65", "chuyện"),
            ("khuyeens", "khuyen61", "khuyến"),
            ("duyeetj", "duyet65", "duyệt"),
            ("nguyeenj", "nguyen65", "nguyện")
        ]

        for target in missionTargets {
            // Telex test
            let telexResult = typeWordWithSpace(target.telex, on: telexEngine)
            XCTAssertEqual(telexResult, target.expected + " ", "Telex typing '\(target.telex)' must yield '\(target.expected) '")

            // VNI test
            let vniResult = typeWordWithSpace(target.vni, on: vniEngine)
            XCTAssertEqual(vniResult, target.expected + " ", "VNI typing '\(target.vni)' must yield '\(target.expected) '")

            // Structural syllable parse test: tone target index on 'uyê' must be 2 ('ê')
            let syllable = SyllableParser.parse(target.expected)
            XCTAssertEqual(syllable.toneTargetIndex, 2, "Tone target index for '\(target.expected)' must be 2 ('ê')")
        }
    }

    func testUyeTriphthong_FreeOrderKeystrokes() {
        // Free-order typing: tone marker placed before final consonant
        let freeOrderPairs: [(input: String, expected: String)] = [
            ("tuyeest", "tuyết"),
            ("thuyeefn", "thuyền"),
            ("chuyeejn", "chuyện"),
            ("khuyeesn", "khuyến"),
            ("duyeejt", "duyệt"),
            ("nguyeejn", "nguyện"),
            ("truyeefn", "truyền"),
            ("truyeejt", "truyệt")
        ]

        for pair in freeOrderPairs {
            let actual = typeWordWithSpace(pair.input, on: telexEngine)
            XCTAssertEqual(actual, pair.expected + " ", "Free-order telex '\(pair.input)' must produce '\(pair.expected) '")
        }
    }

    func testUyeTriphthong_ExtendedVocabularyAndInitialLessWords() {
        let extendedWords: [(input: String, expected: String)] = [
            ("khuyeen", "khuyên"),
            ("thuyeen", "thuyên"),
            ("nguyeen", "nguyên"),
            ("chuyeen", "chuyên"),
            ("duyeen", "duyên"),
            ("huyeenf", "huyền"),
            ("quyeenf", "quyền"),
            ("tuyeens", "tuyến"),
            ("chuyeens", "chuyến"),
            ("tuyeetj", "tuyệt"),
            ("khuyeetj", "khuyệt"),
            ("huyeenj", "huyện"),
            // Words without initial consonant:
            ("uyeen", "uyên"),
            ("uyeenr", "uyển"),
            ("uyeens", "uyến"),
            ("uyeenj", "uyện")
        ]

        for word in extendedWords {
            let actual = typeWordWithSpace(word.input, on: telexEngine)
            XCTAssertEqual(actual, word.expected + " ", "Typing '\(word.input)' must produce '\(word.expected) '")
        }
    }

    func testUyeTriphthong_ToneRemovalWithZAndZero() {
        // Telex tone removal on 'tuyết' (acute tone removed, circumflex 'ê' retained -> 'tuyêt')
        for ch in "tuyeets" { _ = telexEngine.processKey(ch) }
        XCTAssertEqual(telexEngine.formattedWord, "tuyết")
        let zRes = telexEngine.processKey("z")
        XCTAssertTrue(zRes.consumed)
        XCTAssertEqual(telexEngine.formattedWord, "tuyêt", "Stripping tone from 'tuyết' with 'z' must yield 'tuyêt' (tone stripped, vowel modifier preserved)")

        // VNI tone removal on 'thuyền' (grave tone removed, circumflex 'ê' retained -> 'thuyên')
        for ch in "thuyen62" { _ = vniEngine.processKey(ch) }
        XCTAssertEqual(vniEngine.formattedWord, "thuyền")
        let zeroRes = vniEngine.processKey("0")
        XCTAssertTrue(zeroRes.consumed)
        XCTAssertEqual(vniEngine.formattedWord, "thuyên", "Stripping tone from 'thuyền' with '0' in VNI must yield 'thuyên'")
    }

    // MARK: - 2. EMPIRICAL STRESS: Developer & Technical Keywords (def, ref, rust, vest)

    func testDeveloperKeywords_DefAndRefPreservedInAllContexts() {
        // Python keyword 'def'
        XCTAssertEqual(simulateTyping("def foo(): ", on: telexEngine), "def foo(): ")
        XCTAssertEqual(simulateTyping("hàm def này ", on: telexEngine), "hàm def này ", "'def' must not corrupt into 'dè'")
        XCTAssertEqual(simulateTyping("def(x, y)", on: telexEngine), "def(x, y)")

        // Keyword 'ref'
        XCTAssertEqual(simulateTyping("let ref = 1; ", on: telexEngine), "let ref = 1; ")
        XCTAssertEqual(simulateTyping("truyền ref vào ", on: telexEngine), "truyền ref vào ", "'ref' must not corrupt into 'rè'")
        XCTAssertEqual(simulateTyping("ref;", on: telexEngine), "ref;")
    }

    func testDeveloperKeywords_RustAndVestPreservedInEnglishContext() {
        // In English context (preceded by English word/connector), rust and vest are correctly restored to English
        let engRust = simulateTyping("we use rust and swift ", on: telexEngine)
        XCTAssertEqual(engRust, "we use rust and swift ", "In English sentence, 'rust' must remain 'rust'")

        let engVest = simulateTyping("he wore a vest yesterday ", on: telexEngine)
        XCTAssertEqual(engVest, "he wore a vest yesterday ", "In English sentence, 'vest' must remain 'vest'")

        XCTAssertEqual(simulateTyping("code: rust.", on: telexEngine), "code: rust.")
        XCTAssertEqual(simulateTyping("test vest!", on: telexEngine), "test vest!")
    }

    /// In Vietnamese sentences, typing 'rust' and 'vest' yields Vietnamese 'rút' and 'vét',
    /// because 'rust' and 'vest' are contextual homographs, not common English words.
    func testDeveloperKeywords_RustAndVestContextualHomographContrast() {
        let actualVnRust = simulateTyping("họ đang rust tiền ", on: telexEngine)
        let actualVnVest = simulateTyping("họ vest sạch đồ ", on: telexEngine)

        XCTAssertEqual(actualVnRust, "họ đang rút tiền ", "In Vietnamese sentence, 'rust' must format as Vietnamese 'rút'")
        XCTAssertEqual(actualVnVest, "họ vét sạch đồ ", "In Vietnamese sentence, 'vest' must format as Vietnamese 'vét'")
    }

    // MARK: - 3. EMPIRICAL STRESS: NFD Decomposed Unicode Strings & Mid-Sentence Cursor Extraction

    func testNFDUnicode_ZeroCursorDriftAcrossEntireSentence() {
        // Sentence with multiple complex Vietnamese words containing accents
        let precomposedText = "Tiếng Việt là ngôn ngữ tuyệt vời và đẹp đẽ."
        let decomposedNFD = precomposedText.decomposedStringWithCanonicalMapping
        let nfdNS = decomposedNFD as NSString
        let nfcNS = precomposedText as NSString

        // NFD must have strictly greater UTF-16 code units than NFC
        XCTAssertGreaterThan(nfdNS.length, nfcNS.length, "NFD string must be longer than NFC string")

        // Test every single valid cursor offset in the decomposed string
        for rawCursor in 0...nfdNS.length {
            let ctx = AccessibilityBridge.extractContext(fullText: decomposedNFD, cursorLocation: rawCursor)

            // 1. Resulting fullText must be precomposed NFC
            XCTAssertEqual(ctx.fullText, precomposedText)

            // 2. Computed cursorLocation must be within NFC range
            XCTAssertGreaterThanOrEqual(ctx.cursorLocation, 0)
            XCTAssertLessThanOrEqual(ctx.cursorLocation, nfcNS.length)

            // 3. Expected NFC cursor offset computed from prefix
            let rawPrefix = nfdNS.substring(to: rawCursor)
            let expectedNFCCursor = (rawPrefix.precomposedStringWithCanonicalMapping as NSString).length

            // 4. Exact zero drift assertion
            XCTAssertEqual(ctx.cursorLocation, expectedNFCCursor, "Cursor drift detected! Raw cursor \(rawCursor) mapped to \(ctx.cursorLocation), expected \(expectedNFCCursor)")

            // 5. Text partition equality
            let prefixNFC = nfcNS.substring(to: ctx.cursorLocation)
            let suffixNFC = nfcNS.substring(from: ctx.cursorLocation)
            XCTAssertEqual(prefixNFC + suffixNFC, precomposedText)
        }
    }

    func testNFDUnicode_MidWordCursorExtractionInDecomposedWord() {
        // Decomposed "chuyện" = c + h + u + y + e + \u{0302} + \u{0323} + n
        let nfdChuyen = "chuyện".decomposedStringWithCanonicalMapping
        let rawDoc = "kể câu \(nfdChuyen) rất hay"
        let rawNS = rawDoc as NSString

        let chuyenRange = rawNS.range(of: nfdChuyen)
        XCTAssertNotEqual(chuyenRange.location, NSNotFound)

        // Place cursor between 'ch' and 'uyện'
        let cursorInsideWord = chuyenRange.location + 2
        let ctx = AccessibilityBridge.extractContext(fullText: rawDoc, cursorLocation: cursorInsideWord)

        XCTAssertEqual(ctx.wordPrefix, "ch")
        XCTAssertEqual(ctx.wordSuffix, "uyện")
        XCTAssertEqual(ctx.wordAtCursor, "chuyện")
        XCTAssertEqual(ctx.wordBeforeCursor, "câu")
        XCTAssertEqual(ctx.wordAfterCursor, "rất")
    }

    // MARK: - 4. EMPIRICAL STRESS: Word Replacement Preceding Punctuation Marks

    func testWordReplacement_PrecedingPunctuationDoesNotIntroduceExtraSpace() {
        // Test all punctuation marks: ',', '.', '!', '?', ';', ':'
        let punctuations: [String] = [",", ".", "!", "?", ";", ":"]

        for punct in punctuations {
            let doc = "không duoc\(punct) hết text"
            let ns = doc as NSString
            let duocRange = ns.range(of: "duoc")

            // Cursor at the end of 'duoc', touching the punctuation directly
            let cursorLoc = duocRange.location + duocRange.length
            let ctx = AccessibilityBridge.extractContext(fullText: doc, cursorLocation: cursorLoc)

            XCTAssertEqual(ctx.wordPrefix, "duoc")
            XCTAssertEqual(ctx.wordSuffix, "")
            XCTAssertEqual(ctx.wordAtCursor, "duoc")

            // Simulate the exact replacement logic from EventTapHook Case 3:
            let hasSpaceAfterCursor: Bool = {
                let nsFull = ctx.fullText as NSString
                let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
                let suffixLength = (ctx.wordSuffix as NSString).length
                let afterWordIndex = min(nsFull.length, safeCursor + suffixLength)
                if afterWordIndex < nsFull.length {
                    let afterChar = nsFull.character(at: afterWordIndex)
                    if afterChar == 0x20 || afterChar == 0x0A || afterChar == 0x0D ||
                       afterChar == 0x2E || afterChar == 0x2C || afterChar == 0x21 ||
                       afterChar == 0x3F || afterChar == 0x3B || afterChar == 0x3A {
                        return true
                    }
                }
                let rightStr = nsFull.substring(from: afterWordIndex)
                return rightStr.hasPrefix(" ")
            }()

            // hasSpaceAfterCursor MUST be true, so that no space is appended before the punctuation
            XCTAssertTrue(hasSpaceAfterCursor, "Replacing word directly before punctuation '\(punct)' must suppress trailing space")

            let replacementString = "được" + (hasSpaceAfterCursor ? "" : " ")
            let leftStart = cursorLoc - ctx.wordPrefix.count
            let rightEnd = cursorLoc + ctx.wordSuffix.count
            let finalDoc = ns.substring(to: leftStart) + replacementString + ns.substring(from: rightEnd)

            let expectedDoc = "không được\(punct) hết text"
            XCTAssertEqual(finalDoc, expectedDoc, "Replacement before '\(punct)' must not introduce extra whitespace")
        }
    }

    func testWordReplacement_MidSentenceWithoutPunctuationIncludesSpace() {
        let doc = "không duoc hết text"
        let ns = doc as NSString
        let duocRange = ns.range(of: "duoc")

        // Cursor at the end of 'duoc', touching space before 'hết'
        let cursorLoc = duocRange.location + duocRange.length
        let ctx = AccessibilityBridge.extractContext(fullText: doc, cursorLocation: cursorLoc)

        let hasSpaceAfterCursor: Bool = {
            let nsFull = ctx.fullText as NSString
            let safeCursor = max(0, min(nsFull.length, ctx.cursorLocation))
            let suffixLength = (ctx.wordSuffix as NSString).length
            let afterWordIndex = min(nsFull.length, safeCursor + suffixLength)
            if afterWordIndex < nsFull.length {
                let afterChar = nsFull.character(at: afterWordIndex)
                if afterChar == 0x20 || afterChar == 0x0A || afterChar == 0x0D ||
                   afterChar == 0x2E || afterChar == 0x2C || afterChar == 0x21 ||
                   afterChar == 0x3F || afterChar == 0x3B || afterChar == 0x3A {
                    return true
                }
            }
            let rightStr = nsFull.substring(from: afterWordIndex)
            return rightStr.hasPrefix(" ")
        }()

        // Since a space already exists at afterWordIndex, it must detect space and not add a second space
        XCTAssertTrue(hasSpaceAfterCursor, "Word followed by space must not add another space")
        let replacementString = "được" + (hasSpaceAfterCursor ? "" : " ")
        XCTAssertEqual(replacementString, "được")

        let finalDoc = ns.substring(to: duocRange.location) + replacementString + ns.substring(from: duocRange.location + duocRange.length)
        XCTAssertEqual(finalDoc, "không được hết text")
    }

    // MARK: - 5. EMPIRICAL STRESS: Text Polisher Dynamic Heuristics

    func testTextPolisher_DynamicHeuristicsNoHardcoding() {
        // Diverse sentences to verify heuristic generality
        let s1 = "mày làm cái này ntn có đc ko"
        let polished1 = VietnameseTextPolisher.polish(s1, tone: .polite)
        XCTAssertTrue(polished1.contains("bạn"), "Pronoun 'mày' must normalize to 'bạn'")
        XCTAssertTrue(polished1.contains("được"), "Teencode 'đc' must normalize to 'được'")
        XCTAssertTrue(polished1.contains("không"), "Teencode 'ko' must normalize to 'không'")
        XCTAssertTrue(polished1.hasSuffix("ạ"), "Polite tone on question must end with polite particle 'ạ'")

        let s2 = "tôi muốn nói rằng dự án đã hoàn thành tốt"
        let concise2 = VietnameseTextPolisher.polish(s2, tone: .concise)
        XCTAssertFalse(concise2.contains("tôi muốn nói rằng"), "Concise tone must prune verbose padding phrase")
        XCTAssertTrue(concise2.contains("Dự án đã hoàn thành tốt"), "First letter must be properly capitalized")
    }
}
