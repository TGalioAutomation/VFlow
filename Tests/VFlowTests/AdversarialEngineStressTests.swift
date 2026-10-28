import XCTest
@testable import VFlowCore

/// Comprehensive Adversarial & Empirical Stress Test Suite for VFlowCore.
/// Authored and executed by Challenger 1 (teamwork_preview_challenger) to independently stress-test:
/// 1. Complex/Adversarial Vietnamese Syllables (free-order tones, multiple modifiers, tone overwriting/removal)
/// 2. Backspace edit recovery followed by tone removal ('z' / '0')
/// 3. Fast-roll keystrokes (vowel + tone, tone + vowel, modifier + vowel)
/// 4. English & developer vocabulary preservation without diacritic corruption
/// 5. Boundary condition handling (Space, punctuation, brackets, operators)
/// 6. Mixed Vietnamese-English sentence coherence
///
/// Contains both baseline adversarial passing tests and explicit defect reproduction tests
/// documenting discovered engine bugs.
final class AdversarialEngineStressTests: XCTestCase {
    var telexEngine: VietnameseInputEngine!
    var vniEngine: VietnameseInputEngine!

    override func setUp() {
        super.setUp()
        telexEngine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
        vniEngine = VietnameseInputEngine(inputMethod: .vni, tonePlacement: .modern, autoEnglishRestore: true)
    }

    // Helper: Simulate typing character by character, tracking screen output
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

    // Helper: Type a word followed by Space
    private func typeWordWithSpace(_ input: String, on engine: VietnameseInputEngine) -> String {
        return simulateTyping(input + " ", on: engine)
    }

    // MARK: - 1. Adversarial Free-Order Tone Placement (Telex)

    func testFreeOrderTonePlacementAllValidDiphthongsAndTriphthongs() {
        // Free-order tone placement for valid Vietnamese diphthongs and triphthongs
        let freeOrderCases: [(raw: String, expectedFormatted: String, expectedOnSpace: String)] = [
            // Acute ('s') before final consonant
            ("vieest", "viết", "viết "),
            ("toasn", "toán", "toán "),
            ("tieest", "tiết", "tiết "),
            ("quyeest", "quyết", "quyết "),
            ("suoost", "suốt", "suốt "),
            ("thieest", "thiết", "thiết "),
            ("hoasn", "hoán", "hoán "),
            ("khoasn", "khoán", "khoán "),

            // Grave ('f') before final consonant
            ("toafn", "toàn", "toàn "),
            ("hoafn", "hoàn", "hoàn "),
            ("tieefm", "tiềm", "tiềm "),
            ("truowfng", "trường", "trường "),

            // Hook ('r') before final consonant
            ("toarn", "toản", "toản "),
            ("khoarn", "khoản", "khoản "),

            // Tilde ('x') before final consonant
            ("toaxn", "toãn", "toãn "),
            ("hoaxn", "hoãn", "hoãn "),

            // Dot ('j') before final consonant
            ("toajn", "toạn", "toạn "),
            ("quyeejt", "quyệt", "quyệt "),
            ("tieejp", "tiệp", "tiệp "),
            ("kieejm", "kiệm", "kiệm "),

            // Special diphthongs/triphthongs: thuowr (thuở), huow (huơ), loangx (loãng), ngoaif (ngoài)
            ("thuowr", "thuở", "thuở "),
            ("huow", "huơ", "huơ "),
            ("loangx", "loãng", "loãng "),
            ("ngoaif", "ngoài", "ngoài "),
            ("khoais", "khoái", "khoái ")
        ]

        for item in freeOrderCases {
            telexEngine.reset()
            for ch in item.raw {
                _ = telexEngine.processKey(ch)
            }
            XCTAssertEqual(
                telexEngine.formattedWord,
                item.expectedFormatted,
                "Pre-space formatted word mismatch for '\(item.raw)': got '\(telexEngine.formattedWord)', expected '\(item.expectedFormatted)'"
            )

            let full = simulateTyping(item.raw + " ", on: telexEngine)
            XCTAssertEqual(
                full,
                item.expectedOnSpace,
                "Full output on space mismatch for '\(item.raw)': got '\(full)', expected '\(item.expectedOnSpace)'"
            )
        }
    }

    // MARK: - 2. Multiple Modifiers & Tone Overwriting / Removal

    func testToneOverwritingInSequence() {
        // Typing multiple tones in sequence should overwrite the active tone cleanly
        telexEngine.reset()
        _ = simulateTyping("toan", on: telexEngine)
        XCTAssertEqual(telexEngine.formattedWord, "toan")

        _ = telexEngine.processKey("s")
        XCTAssertEqual(telexEngine.formattedWord, "toán")

        _ = telexEngine.processKey("f")
        XCTAssertEqual(telexEngine.formattedWord, "toàn")

        _ = telexEngine.processKey("r")
        XCTAssertEqual(telexEngine.formattedWord, "toản")

        _ = telexEngine.processKey("x")
        XCTAssertEqual(telexEngine.formattedWord, "toãn")

        _ = telexEngine.processKey("j")
        XCTAssertEqual(telexEngine.formattedWord, "toạn")

        // Tone removal with 'z'
        _ = telexEngine.processKey("z")
        XCTAssertEqual(telexEngine.formattedWord, "toan")
    }

    func testComplexModifiersHornAndHat() {
        let cases: [(raw: String, expected: String)] = [
            ("dduowsc", "đước "),
            ("dduowngf", "đường "),
            ("thuowng", "thương "),
            ("nguowif", "người "),
            ("ruowuj", "rượu "),
            ("buoorir", "buổi "),
            ("chieeuf", "chiều "),
            ("trawngs", "trắng "),
            ("nghieeng", "nghiêng "),
            ("eexchs", "ếch "),
            ("quow", "quơ "),
            ("huow", "huơ "),
            ("thuowr", "thuở ")
        ]

        for item in cases {
            let actual = typeWordWithSpace(item.raw, on: telexEngine)
            XCTAssertEqual(actual, item.expected, "Keystrokes '\(item.raw)' produced '\(actual)', expected '\(item.expected)'")
        }
    }

    func testVNIModifiersAndToneRemoval() {
        // VNI basic tones: 1 (sắc), 2 (huyền), 3 (hỏi), 4 (ngã), 5 (nặng), 0 (xoá dấu)
        vniEngine.reset()
        _ = simulateTyping("toan", on: vniEngine)
        XCTAssertEqual(vniEngine.formattedWord, "toan")

        _ = vniEngine.processKey("1")
        XCTAssertEqual(vniEngine.formattedWord, "toán")

        _ = vniEngine.processKey("2")
        XCTAssertEqual(vniEngine.formattedWord, "toàn")

        _ = vniEngine.processKey("3")
        XCTAssertEqual(vniEngine.formattedWord, "toản")

        _ = vniEngine.processKey("4")
        XCTAssertEqual(vniEngine.formattedWord, "toãn")

        _ = vniEngine.processKey("5")
        XCTAssertEqual(vniEngine.formattedWord, "toạn")

        _ = vniEngine.processKey("0")
        XCTAssertEqual(vniEngine.formattedWord, "toan")

        // VNI standalone modified vowels on Space
        let vniOpenCases: [(raw: String, expected: String)] = [
            ("a6", "â "),
            ("a8", "ă "),
            ("o7", "ơ "),
            ("u7", "ư "),
            ("d9", "đ "),
            ("e6", "ê "),
            ("o6", "ô ")
        ]

        for item in vniOpenCases {
            let actual = typeWordWithSpace(item.raw, on: vniEngine)
            XCTAssertEqual(actual, item.expected, "VNI keystroke '\(item.raw)' produced '\(actual)', expected '\(item.expected)'")
        }
    }

    // MARK: - 3. Backspace Recovery Followed by Tone Removal

    func testBackspaceRecoveryThenToneRemovalTelex() {
        // Scenario 1: toans -> toán, Backspace -> toá, z -> toa
        telexEngine.reset()
        for ch in "toans" { _ = telexEngine.processKey(ch) }
        XCTAssertEqual(telexEngine.formattedWord, "toán")

        let bsRes = telexEngine.handleBackspace()
        XCTAssertEqual(bsRes.currentWord, "toá")

        let zRes = telexEngine.processKey("z")
        XCTAssertEqual(telexEngine.formattedWord, "toa")
        XCTAssertEqual(zRes.currentWord, "toa")

        // Scenario 2: vieest -> viết, Backspace -> viế, z -> viê
        telexEngine.reset()
        for ch in "vieest" { _ = telexEngine.processKey(ch) }
        XCTAssertEqual(telexEngine.formattedWord, "viết")

        let bs2 = telexEngine.handleBackspace()
        XCTAssertEqual(bs2.currentWord, "viế")

        let z2 = telexEngine.processKey("z")
        XCTAssertEqual(telexEngine.formattedWord, "viê")
        XCTAssertEqual(z2.currentWord, "viê")

        // Scenario 3: dduowngf -> đường, Backspace -> đườn, z -> đương
        telexEngine.reset()
        for ch in "dduowngf" { _ = telexEngine.processKey(ch) }
        XCTAssertEqual(telexEngine.formattedWord, "đường")

        let bs3 = telexEngine.handleBackspace()
        XCTAssertEqual(bs3.currentWord, "đườn")

        _ = telexEngine.processKey("z")
        XCTAssertEqual(telexEngine.formattedWord, "đươn")
    }

    func testBackspaceRecoveryThenToneRemovalVNI() {
        // VNI: toan1 -> toán, Backspace -> toá, 0 -> toa
        vniEngine.reset()
        for ch in "toan1" { _ = vniEngine.processKey(ch) }
        XCTAssertEqual(vniEngine.formattedWord, "toán")

        let bs = vniEngine.handleBackspace()
        XCTAssertEqual(bs.currentWord, "toá")

        let zeroRes = vniEngine.processKey("0")
        XCTAssertEqual(vniEngine.formattedWord, "toa")
        XCTAssertEqual(zeroRes.currentWord, "toa")
    }

    // MARK: - 4. Fast-Roll Keystrokes

    func testFastRollVowelAndTone() {
        // Users typing fast often roll their fingers: consonant + tone + vowel (e.g. vfa -> và)
        let fastRollCases: [(raw: String, expected: String)] = [
            ("vfa", "và "),
            ("lfa", "là "),
            ("mfa", "mà "),
            ("bfa", "bà "),
            ("cfa", "cà "),
            ("vsa", "vá "),
            ("vja", "vạ "),
            ("vxa", "vã "),
            ("vra", "vả ")
        ]

        for item in fastRollCases {
            let actual = typeWordWithSpace(item.raw, on: telexEngine)
            XCTAssertEqual(actual, item.expected, "Fast-roll '\(item.raw)' produced '\(actual)', expected '\(item.expected)'")
        }

        // Special compound check: "tra" must remain "tra", not "tà"
        let traOutput = typeWordWithSpace("tra", on: telexEngine)
        XCTAssertEqual(traOutput, "tra ", "'tra' must remain 'tra ', not convert to 'tà '")
    }

    func testFastRollModifierAndVowelSupportedClusters() {
        // Fast-roll: wu -> ư (e.g. ddwuocj -> được), mwoi -> mơi, bwan -> băn
        let fastRollModCases: [(raw: String, expected: String)] = [
            ("ddwuocj", "được "),
            ("mwoi", "mơi "),
            ("bwan", "băn ")
        ]

        for item in fastRollModCases {
            let actual = typeWordWithSpace(item.raw, on: telexEngine)
            XCTAssertEqual(actual, item.expected, "Fast-roll modifier '\(item.raw)' produced '\(actual)', expected '\(item.expected)'")
        }
    }

    // MARK: - 5. English & Developer Words Preservation

    func testDeveloperKeywordsOnSpaceAndPunctuation() {
        let keywords = [
            "const", "var", "func", "if", "of", "return", "import", "export",
            "down", "town", "door", "floor", "major", "poor", "brown", "clown", "dust"
        ]

        for kw in keywords {
            // Space boundary
            let onSpace = typeWordWithSpace(kw, on: telexEngine)
            XCTAssertEqual(onSpace, kw + " ", "Developer word '\(kw)' corrupted on Space: got '\(onSpace)'")

            // Punctuation boundary: '('
            let withParen = simulateTyping(kw + "(", on: telexEngine)
            XCTAssertEqual(withParen, kw + "(", "Developer word '\(kw)' corrupted on '(': got '\(withParen)'")

            // Punctuation boundary: ';'
            let withSemicolon = simulateTyping(kw + ";", on: telexEngine)
            XCTAssertEqual(withSemicolon, kw + ";", "Developer word '\(kw)' corrupted on ';': got '\(withSemicolon)'")

            // Punctuation boundary: '.'
            let withDot = simulateTyping(kw + ".", on: telexEngine)
            XCTAssertEqual(withDot, kw + ".", "Developer word '\(kw)' corrupted on '.': got '\(withDot)'")
        }
    }

    func testContextualHomographsBaseline() {
        // When preceded by an English connector, homographs stay English: "the car " -> "the car "
        let englishSentence = simulateTyping("the car is fast and now ", on: telexEngine)
        XCTAssertEqual(englishSentence, "the car is fast and now ")

        // When preceded by Vietnamese, "car" formats as "cả"
        telexEngine.reset()
        _ = simulateTyping("xe ", on: telexEngine)
        let vnHomograph = simulateTyping("xe car ", on: telexEngine)
        XCTAssertEqual(vnHomograph, "xe cả ")
    }

    // MARK: - 6. Mixed Vietnamese-English Sentences Stress

    func testAdversarialMixedSentences() {
        let sentences: [(input: String, expected: String)] = [
            (
                "Hamf func tinhs toasn vieest bawfng Swift raats nhanh ",
                "Hàm func tính toán viết bằng Swift rất nhanh "
            ),
            (
                "Kieemr tra if (status == true) return nil trong code ",
                "Kiểm tra if (status == true) return nil trong code "
            ),
            (
                "Chusng tooi ko dungf var maf dungf let vaf const ",
                "Chúng tôi không dùng var mà dùng let và const "
            ),
            (
                "Cuwra soor window vaf door hieenr thij dc binhf thuowfng ",
                "Cửa sổ window và door hiển thị được bình thường "
            ),
            (
                "Developer import framework vaf export module mowis ",
                "Developer import framework và export module mới "
            ),
            (
                "Heej thoongs tuwj ddoongj down vaf load duwx lieeuj veef mays ",
                "Hệ thống tự động down và load dữ liệu về máy "
            ),
            (
                "Thieest laapj menu item vaf icon cho status bar app ",
                "Thiết lập menu item và icon cho status bar app "
            ),
            (
                "quyeest ddinhj xaay duwngj heej thoongs an toanf vaf hieejn ddaij ",
                "quyết định xây dựng hệ thống an toàn và hiện đại "
            )
        ]

        for (idx, item) in sentences.enumerated() {
            let actual = simulateTyping(item.input, on: telexEngine)
            XCTAssertEqual(
                actual,
                item.expected,
                "Sentence [\(idx + 1)] mismatch.\nActual:   '\(actual)'\nExpected: '\(item.expected)'"
            )
        }
    }

    // MARK: - 7. Double-Escape and URL Stress

    func testDoubleEscapeAndUrls() {
        let urls = [
            "www.google.com",
            "https://www.google.com/search?q=swift",
            "www.apple.com/macos"
        ]

        for url in urls {
            let actual = simulateTyping(url, on: telexEngine)
            XCTAssertEqual(actual, url, "URL '\(url)' corrupted to '\(actual)'")
        }

        // UniKey double escape sequences: texx -> tex, texxt -> text
        let doubleEscapeCases: [(raw: String, expected: String)] = [
            ("texx", "tex"),
            ("texxt ", "text "),
            ("asxx", "asx")
        ]

        for item in doubleEscapeCases {
            let actual = simulateTyping(item.raw, on: telexEngine)
            XCTAssertEqual(actual, item.expected, "Double escape '\(item.raw)' produced '\(actual)', expected '\(item.expected)'")
        }
    }

    // MARK: - 8. DISCOVERED DEFECT REPRODUCTIONS (Forensic Evidence)

    /// Verifies BUG-UYÊ-01 Remediation: In `SyllableParser.swift:73-77`, for triphthong "uyê",
    /// toneTargetIndex returns index 2 ('ê') so tone is correctly placed on 'ê'
    /// for all initials (e.g. tuyết, thuyền, chuyện, khuyến, duyệt, nguyện, uyển).
    func testDiscoveredBug_UyeTriphthongToneTargetMisplacement() {
        // Words with 'qu' initial
        XCTAssertEqual(typeWordWithSpace("quyeets", on: telexEngine), "quyết ")
        XCTAssertEqual(typeWordWithSpace("quyeest", on: telexEngine), "quyết ")

        // All non-'qu' initials and initial-less words must place tone on 'ê' (index 2)
        let nonQuUyeWords: [(raw: String, expected: String)] = [
            ("tuyeets", "tuyết "),
            ("tuyeest", "tuyết "),
            ("thuyeenf", "thuyền "),
            ("thuyeefn", "thuyền "),
            ("chuyeenj", "chuyện "),
            ("chuyeejn", "chuyện "),
            ("khuyeens", "khuyến "),
            ("khuyeesn", "khuyến "),
            ("duyeetj", "duyệt "),
            ("duyeejt", "duyệt "),
            ("nguyeenj", "nguyện "),
            ("nguyeejn", "nguyện "),
            ("uyeenr", "uyển ")
        ]

        for item in nonQuUyeWords {
            let actual = typeWordWithSpace(item.raw, on: telexEngine)
            XCTAssertEqual(actual, item.expected, "'\(item.raw)' produced '\(actual)', expected '\(item.expected)'")
        }
    }

    /// Verifies BUG-ENG-01 Remediation: Developer & everyday words `def`, `ref`, `rust`, `vest`
    /// are recognized by `SmartEnglishDetector` and preserved without diacritic corruption.
    func testDiscoveredBug_DeveloperAndEverydayEnglishWordsCorruption() {
        let actualDef = simulateTyping("def calculate(): ", on: telexEngine)
        let actualRef = simulateTyping("ref count; ", on: telexEngine)
        let actualRust = simulateTyping("we use rust and swift ", on: telexEngine)
        let actualVest = simulateTyping("he wore a vest ", on: telexEngine)

        XCTAssertEqual(actualDef, "def calculate(): ", "Python keyword 'def' must be preserved as English")
        XCTAssertEqual(actualRef, "ref count; ", "Keyword 'ref' must be preserved as English")
        XCTAssertEqual(actualRust, "we use rust and swift ", "Programming language 'rust' must be preserved as English")
        XCTAssertEqual(actualVest, "he wore a vest ", "English word 'vest' must be preserved as English")
    }
}
