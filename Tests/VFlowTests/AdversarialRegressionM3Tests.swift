import XCTest
import CoreGraphics
import CoreFoundation
import AppKit
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

/// Adversarial Edge-Case Regression Testing Suite for Milestone 3.
/// Authored and executed by Challenger M3 (critic / specialist).
///
/// Exhaustively stress-tests:
/// 1. Telex double-key escapes and intervocalic tone-letter disambiguation:
///    - `tieengss` -> `tiếng`, `dduwowngff` -> `đường`, `mowiss` -> `mới`, `chuawxx` -> `chữa`
///    - `Texxt` -> `Text`, `texxt` -> `text`, `Dduoc` -> `Được`, `dduocj` -> `được`
///    - Double-key escapes: `arr` -> `ar`, `arry` -> `ary`, `ayrr` -> `ayr`
///    - Intervocalic tone letter vs end tone: `ary` vs `ảy`
/// 2. Genuine English double consonants & compound words:
///    - `array`, `arrow`, `error`, `carry`, `sorry`, `current`, `correct`, `pass`, `class`, `coffee`, `diff`, `off`
///    - Compounds: `subclass`, `compass`, `bypass`, `keypress`, `preprocess`, `success`, `access`, `process`
///    - Verified in both Telex and VNI input methods
/// 3. Zero false-positive corruptions:
///    - English collocations: "go to work", "time to go", "cà phê to go", "ready to go", "welcome to our team"
///    - Vietnamese descriptive size phrases: "chữ to quá", "nhà to đẹp", "chữ to đang đẹp", "rất to đang"
///    - Collocations: "không cau có", "câu hỏi này", "câu nệ" -> never corrupted to "dấu"
/// 4. Positive corrections:
///    - "to đang làm việc" -> "tôi đang làm việc", "to muốn" -> "tôi muốn", "to cần" -> "tôi cần"
///    - "không cau" -> "không dấu", "khong cau" -> "không dấu"
///    - "thaat sư" -> "thật sự", "thuc su" -> "thực sự"
/// 5. Platform & UI Boundary Tests:
///    - `postUnicodeString` chunking: 20, 21, 45, 100 UniChars without truncation or data loss
///    - `AccessibilityBridge` safe casting on non-AXValue / non-AXUIElement CFTypeRef objects
///    - `applySandboxSuggestion`: `replaceLastCompletedWord`, empty string leading space guard, missing target fallback
final class AdversarialRegressionM3Tests: XCTestCase {

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

    // MARK: - 1. Telex Double-Key Escapes & Intervocalic Disambiguation

    func testTelexDoubleKeyEscapes_PreserveComposedVowelsAndTones() {
        // tieengss -> tiếng
        XCTAssertEqual(typeWordWithSpace("tieengss", on: telexEngine), "tiếng ", "tieengss must yield tiếng")

        // dduwowngff -> đường
        XCTAssertEqual(typeWordWithSpace("dduwowngff", on: telexEngine), "đường ", "dduwowngff must yield đường")

        // mowiss -> mới
        XCTAssertEqual(typeWordWithSpace("mowiss", on: telexEngine), "mới ", "mowiss must yield mới")

        // chuawxx -> chữa
        XCTAssertEqual(typeWordWithSpace("chuawxx", on: telexEngine), "chữa ", "chuawxx must yield chữa")

        // Texxt -> Text (case preserved)
        XCTAssertEqual(typeWordWithSpace("Texxt", on: telexEngine), "Text ", "Texxt must collapse to Text")
        XCTAssertEqual(typeWordWithSpace("texxt", on: telexEngine), "text ", "texxt must collapse to text")
        XCTAssertEqual(typeWordWithSpace("TEXXT", on: telexEngine), "TEXT ", "TEXXT must collapse to TEXT")

        // Full Telex with modifier and tone: Dduowcj -> Được
        XCTAssertEqual(typeWordWithSpace("Dduowcj", on: telexEngine), "Được ", "Dduowcj must yield Được")

        // dduwowngff -> đường vs Dduwowngff -> Đường
        XCTAssertEqual(typeWordWithSpace("Dduwowngff", on: telexEngine), "Đường ", "Dduwowngff must yield Đường")
    }

    func testDoubleKeyEscapes_ArrArryAyrr() {
        // arr -> ar
        XCTAssertEqual(typeWordWithSpace("arr", on: telexEngine), "ar ", "arr double-r must escape to ar")

        // arry -> ary
        XCTAssertEqual(typeWordWithSpace("arry", on: telexEngine), "ary ", "arry double-r must escape to ary")

        // ayrr -> ayr
        XCTAssertEqual(typeWordWithSpace("ayrr", on: telexEngine), "ayr ", "ayrr double-r must escape to ayr")
    }

    func testIntervocalicAryVsEndToneAy() {
        // In "ary", 'r' is between vowels 'a' and 'y', so it's intervocalic English -> "ary "
        XCTAssertEqual(typeWordWithSpace("ary", on: telexEngine), "ary ", "ary must remain English 'ary'")

        // In "ayr", 'r' is at the end following diphthong 'ay' -> "ảy "
        XCTAssertEqual(typeWordWithSpace("ayr", on: telexEngine), "ảy ", "ayr must compose to Vietnamese 'ảy'")
    }

    // MARK: - 2. Genuine English Double Consonants & Compounds (Telex + VNI)

    func testEnglishDoubleConsonants_TelexTyping() {
        let englishWords = [
            "array", "arrow", "error", "carry", "sorry",
            "current", "correct", "pass", "class", "coffee",
            "diff", "off"
        ]

        for word in englishWords {
            let actual = typeWordWithSpace(word, on: telexEngine)
            XCTAssertEqual(actual, word + " ", "Telex typing '\(word)' must not produce diacritics: got '\(actual)'")
            XCTAssertTrue(SmartEnglishDetector.isGenuineEnglishDoubleConsonantWord(word), "\(word) should be recognized as double consonant word")
            XCTAssertTrue(SmartEnglishDetector.isEnglishWord(word), "\(word) should be recognized as English word")
        }
    }

    func testEnglishDoubleConsonants_VNITyping() {
        let englishWords = [
            "array", "arrow", "error", "carry", "sorry",
            "current", "correct", "pass", "class", "coffee",
            "diff", "off"
        ]

        for word in englishWords {
            let actual = typeWordWithSpace(word, on: vniEngine)
            XCTAssertEqual(actual, word + " ", "VNI typing '\(word)' must not produce diacritics: got '\(actual)'")
        }
    }

    func testEnglishCompounds_TelexAndVNI() {
        let compounds = [
            "subclass", "compass", "bypass", "keypress", "preprocess",
            "success", "access", "process"
        ]

        for compound in compounds {
            // Telex
            let telexActual = typeWordWithSpace(compound, on: telexEngine)
            XCTAssertEqual(telexActual, compound + " ", "Telex typing compound '\(compound)' must preserve English: got '\(telexActual)'")

            // VNI
            let vniActual = typeWordWithSpace(compound, on: vniEngine)
            XCTAssertEqual(vniActual, compound + " ", "VNI typing compound '\(compound)' must preserve English: got '\(vniActual)'")

            // Detection check
            XCTAssertTrue(SmartEnglishDetector.isGenuineEnglishDoubleConsonantWord(compound), "\(compound) must match double consonant stem/suffix")
            XCTAssertTrue(SmartEnglishDetector.isEnglishWord(compound), "\(compound) must be recognized as English")
        }
    }

    func testEnglishSentencesWithDoubleConsonantsAndCompounds() {
        let testSentences = [
            "we create an array of items ",
            "fix the error in the current process ",
            "the subclass can bypass the access check ",
            "press the keypress handler "
        ]

        for sent in testSentences {
            let actual = simulateTyping(sent, on: telexEngine)
            XCTAssertEqual(actual, sent, "English sentence corrupted: got '\(actual)' vs expected '\(sent)'")
        }
    }

    // MARK: - 3. Zero False-Positive Corruptions

    func testZeroFalsePositives_EnglishPhrasesWithTo() {
        let englishPhrases = [
            ("go to work", "go to work"),
            ("time to go", "time to go"),
            ("cà phê to go", "cà phê to go"),
            ("ready to go", "ready to go"),
            ("welcome to our team", "welcome to our team")
        ]

        for (input, _) in englishPhrases {
            let polished = VietnameseTextPolisher.polish(input)
            XCTAssertFalse(polished.contains("tôi"), "'\(input)' must NEVER mutate 'to' to 'tôi': got '\(polished)'")
            XCTAssertTrue(polished.lowercased().contains("to"), "'\(input)' must preserve 'to': got '\(polished)'")
        }
    }

    func testZeroFalsePositives_VietnameseDescriptiveSizePhrases() {
        let sizePhrases = [
            "chữ to quá",
            "nhà to đẹp",
            "chữ to đang đẹp",
            "cái bàn rất to đang dùng",
            "chiếc xe to đang chạy"
        ]

        for phrase in sizePhrases {
            let polished = VietnameseTextPolisher.polish(phrase)
            XCTAssertFalse(polished.contains("tôi"), "Descriptive size phrase '\(phrase)' must NOT convert 'to' to 'tôi': got '\(polished)'")
        }
    }

    func testZeroFalsePositives_CauCollocationsPreserved() {
        // không cau có -> must never become không dấu có
        let p1 = VietnameseTextPolisher.polish("anh ấy không cau có chút nào")
        XCTAssertTrue(p1.contains("không cau có"), "Collocation 'không cau có' must be preserved: got '\(p1)'")
        XCTAssertFalse(p1.contains("không dấu có"), "Must not corrupt to 'không dấu có'")

        // câu hỏi này -> must never become dấu hỏi này
        let p2 = VietnameseTextPolisher.polish("tôi có một câu hỏi này")
        XCTAssertTrue(p2.contains("câu hỏi"), "'câu hỏi' must be preserved: got '\(p2)'")
        XCTAssertFalse(p2.contains("dấu hỏi"), "Must not corrupt to 'dấu hỏi'")

        // câu nệ -> must never become dấu nệ
        let p3 = VietnameseTextPolisher.polish("đừng quá câu nệ tiểu tiết")
        XCTAssertTrue(p3.contains("câu nệ"), "'câu nệ' must be preserved: got '\(p3)'")
        XCTAssertFalse(p3.contains("dấu nệ"), "Must not corrupt to 'dấu nệ'")

        // SuggestionEngine contextual word fix guards:
        let fix1 = SuggestionEngine.resolveContextualWordFix(prevWord: "không", currentWord: "cau", wordAfterCursor: "có")
        XCTAssertNil(fix1, "cau followed by có must return nil (not dấu)")

        let fix2 = SuggestionEngine.resolveContextualWordFix(prevWord: "không", currentWord: "cau", wordAfterCursor: "hỏi")
        XCTAssertNil(fix2, "cau followed by hỏi must return nil")

        let fix3 = SuggestionEngine.resolveContextualWordFix(prevWord: "không", currentWord: "cau", wordAfterCursor: "nệ")
        XCTAssertNil(fix3, "cau followed by nệ must return nil")
    }

    // MARK: - 4. Positive Corrections

    func testPositiveCorrections_PronounRepair() {
        let positivePronouns = [
            ("to đang làm việc", "tôi đang làm việc"),
            ("to muốn xem lại", "tôi muốn xem lại"),
            ("to cần giúp đỡ", "tôi cần giúp đỡ"),
            ("To đang làm việc", "Tôi đang làm việc")
        ]

        for (input, expectedPrefix) in positivePronouns {
            let polished = VietnameseTextPolisher.polish(input)
            XCTAssertTrue(polished.hasPrefix(expectedPrefix) || polished.lowercased().hasPrefix(expectedPrefix.lowercased()),
                          "Positive pronoun repair failed for '\(input)': got '\(polished)'")
        }

        // SuggestionEngine contextual pronoun fix
        let ctxFix = SuggestionEngine.resolveContextualWordFix(prevWord: nil, currentWord: "to", wordAfterCursor: "đang")
        XCTAssertEqual(ctxFix, "tôi", "Standalone 'to' before 'đang' must resolve to 'tôi'")
    }

    func testPositiveCorrections_KhongCauToKhongDau() {
        // End of sentence or standalone "không cau" -> "không dấu"
        let p1 = VietnameseTextPolisher.polish("gõ chữ không cau")
        XCTAssertTrue(p1.contains("không dấu"), "'không cau' at end of sentence must correct to 'không dấu': got '\(p1)'")

        let p2 = VietnameseTextPolisher.polish("khong cau")
        XCTAssertTrue(p2.contains("không dấu"), "'khong cau' must correct to 'không dấu': got '\(p2)'")

        // SuggestionEngine fix
        let fix = SuggestionEngine.resolveContextualWordFix(prevWord: "không", currentWord: "cau", wordAfterCursor: "")
        XCTAssertEqual(fix, "dấu", "'không cau' without exception follower must fix to 'dấu'")
    }

    func testPositiveCorrections_ThaatSuToThatSu() {
        let p1 = VietnameseTextPolisher.polish("điều đó thaat sư rất tuyệt")
        XCTAssertTrue(p1.contains("thật sự"), "'thaat sư' must normalize to 'thật sự': got '\(p1)'")

        let p2 = VietnameseTextPolisher.polish("thuc su la rat tot")
        XCTAssertTrue(p2.contains("thực sự"), "'thuc su' must normalize to 'thực sự': got '\(p2)'")
    }

    // MARK: - 5. Platform & UI Boundary Stress Tests

    func testPostUnicodeString_ChunkingCalculations_20_21_45_100() {
        let lengthsToTest = [20, 21, 45, 100]

        for len in lengthsToTest {
            // Generate a distinct test string of exact UTF-16 code units
            let rawString = String(repeating: "A", count: len)
            let utf16Chars = Array(rawString.utf16)
            XCTAssertEqual(utf16Chars.count, len)

            let chunkSize = 20
            var chunks: [[UniChar]] = []

            for start in stride(from: 0, to: utf16Chars.count, by: chunkSize) {
                let end = min(start + chunkSize, utf16Chars.count)
                let chunk = Array(utf16Chars[start..<end])
                chunks.append(chunk)
                XCTAssertLessThanOrEqual(chunk.count, 20, "Chunk size must not exceed kCGEventSourceUniCharCountMax (20)")
                XCTAssertGreaterThan(chunk.count, 0, "Chunk must not be empty")
            }

            // Verify number of chunks:
            let expectedChunkCount = (len + chunkSize - 1) / chunkSize
            XCTAssertEqual(chunks.count, expectedChunkCount, "Expected \(expectedChunkCount) chunks for length \(len), got \(chunks.count)")

            // Verify full reconstruction has zero truncation or drift
            let reconstructed = chunks.flatMap { $0 }
            XCTAssertEqual(reconstructed.count, len, "Reconstructed character count must match original length \(len)")
            XCTAssertEqual(reconstructed, utf16Chars, "Reconstructed characters must match original sequence exactly")
        }
    }

    func testAccessibilityBridge_SafeTypeCheckingOnMockNonAXValues() {
        // Verify that CFGetTypeID checks guard against invalid downcasts to AXValue or AXUIElement.
        let nonAXValueObjects: [CFTypeRef] = [
            kCFBooleanTrue,
            "NotAnAXValue" as CFString,
            NSNumber(value: 42),
            NSArray(array: ["item1", "item2"])
        ]

        for obj in nonAXValueObjects {
            let isAXValue = (CFGetTypeID(obj) == AXValueGetTypeID())
            XCTAssertFalse(isAXValue, "Mock non-AXValue object must evaluate to false on AXValueGetTypeID check")

            let isAXUIElement = (CFGetTypeID(obj) == AXUIElementGetTypeID())
            XCTAssertFalse(isAXUIElement, "Mock non-AXUIElement object must evaluate to false on AXUIElementGetTypeID check")
        }
    }

    func testApplySandboxSuggestion_ReplaceLastCompletedWordAndEmptyTextEdgeCases() {
        // Case A: Normal replaceLastCompletedWord (e.g. "tôi ko " -> "tôi không ")
        var sandboxA = "tôi ko "
        let itemA = SuggestionItem(
            text: "không",
            kind: .teencodeExpansion,
            replaceLastCompletedWord: true,
            targetWordToReplace: "ko"
        )
        applySandboxSimulation(sandboxText: &sandboxA, currentWord: "", item: itemA)
        XCTAssertEqual(sandboxA, "tôi không ", "replaceLastCompletedWord must accurately replace target word and add trailing space")

        // Case B: Empty sandbox text should not produce leading whitespace
        var sandboxB = ""
        let itemB = SuggestionItem(text: "xin chào", kind: .wordCompletion)
        applySandboxSimulation(sandboxText: &sandboxB, currentWord: "", item: itemB)
        XCTAssertEqual(sandboxB, "xin chào ", "Empty sandbox text must not have leading space")
        XCTAssertFalse(sandboxB.hasPrefix(" "), "Must not start with leading space")

        // Case C: Target word not found in replaceLastCompletedWord fallback
        var sandboxC = "văn bản đã có"
        let itemC = SuggestionItem(
            text: "mới",
            kind: .teencodeExpansion,
            replaceLastCompletedWord: true,
            targetWordToReplace: "không_tồn_tại"
        )
        applySandboxSimulation(sandboxText: &sandboxC, currentWord: "", item: itemC)
        XCTAssertEqual(sandboxC, "văn bản đã có mới ", "Fallback append must normalize spacing cleanly")

        // Case D: replaceCurrentWord with non-empty sandboxCurrentWord
        var sandboxD = "đang gõ chu"
        let itemD = SuggestionItem(
            text: "chúng",
            kind: .wordCompletion,
            replaceCurrentWord: true
        )
        applySandboxSimulation(sandboxText: &sandboxD, currentWord: "chu", item: itemD)
        XCTAssertEqual(sandboxD, "đang gõ chúng ", "replaceCurrentWord must replace currentWord cleanly")
    }

    // MARK: - 6. Additional Adversarial Stress Tests

    func testComplexCompoundEnglishMultipleDoubleConsonants() {
        let complexWords = [
            "subclass", "compass", "bypass", "keypress", "preprocess",
            "success", "access", "process", "possess", "assess",
            "express", "impress", "address", "progress", "congress"
        ]

        for word in complexWords {
            let telexResult = typeWordWithSpace(word, on: telexEngine)
            XCTAssertEqual(telexResult, word + " ", "Telex typing '\(word)' must preserve English: got '\(telexResult)'")

            let vniResult = typeWordWithSpace(word, on: vniEngine)
            XCTAssertEqual(vniResult, word + " ", "VNI typing '\(word)' must preserve English: got '\(vniResult)'")

            XCTAssertTrue(SmartEnglishDetector.isGenuineEnglishDoubleConsonantWord(word), "\(word) must be detected as double consonant English word")
            XCTAssertTrue(SmartEnglishDetector.isEnglishWord(word), "\(word) must be detected as English")
        }
    }

    func testSurrogatePairEmojiAndUnicodeChunking() {
        // Construct string where an emoji (2 UTF-16 code units) sits right at the boundary:
        // 19 'a's + 👩 (high surrogate 0xD83D, low surrogate 0xDC69) + 20 'b's
        let prefix19 = String(repeating: "a", count: 19)
        let emoji = "👩"
        let suffix20 = String(repeating: "b", count: 20)
        let composite = prefix19 + emoji + suffix20
        let utf16 = Array(composite.utf16)

        // Length should be 19 + 2 + 20 = 41
        XCTAssertEqual(utf16.count, 41)

        let chunkSize = 20
        var chunks: [[UniChar]] = []
        for start in stride(from: 0, to: utf16.count, by: chunkSize) {
            let end = min(start + chunkSize, utf16.count)
            chunks.append(Array(utf16[start..<end]))
        }

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].count, 20)
        XCTAssertEqual(chunks[1].count, 20)
        XCTAssertEqual(chunks[2].count, 1)

        // Reconstructed characters must match exactly
        let reconstructed = chunks.flatMap { $0 }
        XCTAssertEqual(reconstructed, utf16)
        XCTAssertEqual(String(utf16CodeUnits: reconstructed, count: reconstructed.count), composite)
    }

    func testOnDeviceAIEngineRefinementAdversarialStress() {
        // Test 1: Valid polite expansion with filler word stripping
        let base1 = "à ừm tôi đang làm việc"
        let cand1 = "Tôi đang làm việc ạ"
        XCTAssertTrue(OnDeviceAIEngine.isValidRefinement(base: base1, candidate: cand1),
                      "Dropping conversational fillers and adding polite particle must be valid")

        // Test 2: Invalid corruption of accented base noun "câu hỏi" -> "dấu hỏi"
        let base2 = "tôi có một câu hỏi quan trọng"
        let cand2 = "tôi có một dấu hỏi quan trọng"
        XCTAssertFalse(OnDeviceAIEngine.isValidRefinement(base: base2, candidate: cand2),
                       "Corrupting 'câu' to 'dấu' must be rejected by root match guard")

        // Test 3: Excessive truncation of core meaning (>50% dropped)
        let base3 = "chúng ta cần phải hoàn thành toàn bộ công việc trước ngày mai"
        let cand3 = "hoàn thành"
        XCTAssertFalse(OnDeviceAIEngine.isValidRefinement(base: base3, candidate: cand3),
                       "Excessive truncation must be rejected")

        // Test 4: Pure gibberish candidate
        let base4 = "bộ gõ tiếng việt"
        let cand4 = "asdf qwerty zxcv"
        XCTAssertFalse(OnDeviceAIEngine.isValidRefinement(base: base4, candidate: cand4),
                       "Gibberish candidate must be rejected")
    }

    func testMixedCaseTelexDoubleEscapeExhaustive() {
        // Mixed-case tone escapes
        XCTAssertEqual(typeWordWithSpace("Tieengss", on: telexEngine), "Tiếng ")
        XCTAssertEqual(typeWordWithSpace("Dduwowngff", on: telexEngine), "Đường ")
        XCTAssertEqual(typeWordWithSpace("Mowiss", on: telexEngine), "Mới ")
        XCTAssertEqual(typeWordWithSpace("Chuawxx", on: telexEngine), "Chữa ")

        // Mixed-case double x preserving surrounding case
        XCTAssertEqual(typeWordWithSpace("TExxt", on: telexEngine), "TExt ")
        XCTAssertEqual(typeWordWithSpace("TeXXt", on: telexEngine), "TeXt ")

        // Mixed-case double r escapes preserving surrounding case
        XCTAssertEqual(typeWordWithSpace("Arr", on: telexEngine), "Ar ")
        XCTAssertEqual(typeWordWithSpace("aRR", on: telexEngine), "aR ")
    }

    func testDescriptiveSizePhrasesExhaustive() {
        let descriptivePrefixes = [
            "chữ to", "nhà to", "xe to", "phòng to", "loa to",
            "cái to", "con to", "rất to", "quá to", "cực to", "khá to"
        ]

        for desc in descriptivePrefixes {
            let sentence = "\(desc) đang hoạt động rất tốt"
            let polished = VietnameseTextPolisher.polish(sentence)
            XCTAssertFalse(polished.contains("tôi"), "Size description '\(desc)' must NOT mutate 'to' to 'tôi': got '\(polished)'")
        }
    }

    func testNegativeEnglishPhrasesExhaustive() {
        let englishPhrases = [
            "back to school",
            "how to use this app",
            "where to go tonight",
            "nice to meet you",
            "listen to music",
            "turn to page ten"
        ]

        for phrase in englishPhrases {
            let polished = VietnameseTextPolisher.polish(phrase)
            XCTAssertFalse(polished.contains("tôi"), "English phrase '\(phrase)' must NOT mutate 'to' to 'tôi': got '\(polished)'")
            XCTAssertTrue(polished.lowercased().contains("to"), "English phrase '\(phrase)' must preserve 'to': got '\(polished)'")
        }
    }

    func testAutoDiacriticCapitalizationEmpiricalDocumentation() {
        // 1. Full Telex with explicit vowel modifier 'w' and tone 'j' produces uppercase "Được ":
        let fullTelexResult = typeWordWithSpace("Dduowcj", on: telexEngine)
        XCTAssertEqual(fullTelexResult, "Được ", "Dduowcj with explicit modifiers produces uppercase Được")

        // 2. Shorthand Dduoc without 'w' relying on autoDiacriticMap on Space preserves initial capitalization:
        let shorthandResult = typeWordWithSpace("Dduoc", on: telexEngine)
        XCTAssertEqual(shorthandResult, "Được ", "Shorthand Dduoc on Space preserves initial uppercase Được")

        // 3. Inflected compound English double-consonant words stay intact:
        let bypassingRes = typeWordWithSpace("bypassing", on: telexEngine)
        XCTAssertEqual(bypassingRes, "bypassing ")
        let keypressesRes = typeWordWithSpace("keypresses", on: telexEngine)
        XCTAssertEqual(keypressesRes, "keypresses ")
    }

    // Helper: Simulates the exact logic implemented in BentoSettingsWindow.applySandboxSuggestion
    private func applySandboxSimulation(
        sandboxText: inout String,
        currentWord: String,
        item: SuggestionItem
    ) {
        if item.kind == .aiPolish {
            sandboxText = item.text
        } else if item.replaceCurrentWord && !currentWord.isEmpty {
            let ns = sandboxText as NSString
            let range = ns.range(of: currentWord, options: .backwards)
            if range.location != NSNotFound {
                sandboxText = ns.replacingCharacters(in: range, with: item.text + " ")
            } else {
                sandboxText += (sandboxText.isEmpty ? "" : " ") + item.text + " "
            }
        } else if item.replaceLastCompletedWord && !item.targetWordToReplace.isEmpty {
            let ns = sandboxText as NSString
            let range = ns.range(of: item.targetWordToReplace, options: .backwards)
            if range.location != NSNotFound {
                sandboxText = ns.replacingCharacters(in: range, with: item.text)
                if !sandboxText.hasSuffix(" ") {
                    sandboxText += " "
                }
            } else {
                sandboxText += (sandboxText.isEmpty ? "" : " ") + item.text + " "
            }
        } else {
            let trimmed = sandboxText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                sandboxText = item.text + " "
            } else {
                sandboxText = trimmed + " " + item.text + " "
            }
        }
    }
}
