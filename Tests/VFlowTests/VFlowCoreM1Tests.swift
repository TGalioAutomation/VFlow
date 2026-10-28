import XCTest
@testable import VFlowCore

/// Targeted regression and unit test suite verifying fixes for R1-BUG-01 through R1-BUG-10.
final class VFlowCoreM1Tests: XCTestCase {
    var engine: VietnameseInputEngine!

    override func setUp() {
        super.setUp()
        engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
    }

    // Helper to simulate keystrokes on the active engine instance
    private func typeString(_ str: String) -> EngineResult {
        var lastResult = EngineResult()
        for ch in str {
            lastResult = engine.processKey(ch)
        }
        return lastResult
    }

    private func fullOutput(for input: String) -> String {
        engine.reset()
        var output = ""
        for ch in input {
            let res = engine.processKey(ch)
            if res.consumed {
                if res.backspaceCount > 0 {
                    output = String(output.dropLast(min(res.backspaceCount, output.count)))
                }
                output += res.replacementText
            } else {
                output.append(ch)
            }
        }
        return output
    }

    // MARK: - R1-BUG-01: Free-order Telex tone endings (-st, -sn, -rn)

    func testR1_BUG_01_FreeOrderTelexToneBeforeFinalConsonant() {
        let cases: [(raw: String, expectedFormatted: String, expectedOnSpace: String)] = [
            ("vieest", "viết", "viết "),
            ("toasn", "toán", "toán "),
            ("toarn", "toản", "toản "),
            ("tieest", "tiết", "tiết "),
            ("suoost", "suốt", "suốt "),
            ("quyeest", "quyết", "quyết "),
            ("thieest", "thiết", "thiết "),
            ("suost", "suót", "suót "),
            ("thiest", "thiét", "thiét ")
        ]

        for item in cases {
            engine.reset()
            _ = typeString(item.raw)
            XCTAssertEqual(engine.formattedWord, item.expectedFormatted, "Pre-space formatted word failed for \(item.raw)")

            let spaceRes = engine.processKey(" ")
            let finalOutput = spaceRes.consumed ? spaceRes.replacementText : spaceRes.currentWord + " "
            XCTAssertEqual(finalOutput, item.expectedOnSpace, "Word \(item.raw) falsely reverted on Space")
        }
    }

    // MARK: - R1-BUG-02: Vietnamese shorthand tokens (ko, dc, đc, trc, ntn, mn)

    func testR1_BUG_02_ShorthandTokensExpandOnSpace() {
        let shorthands: [(raw: String, expected: String)] = [
            ("ko", "không "),
            ("dc", "được "),
            ("đc", "được "),
            ("trc", "trước "),
            ("ntn", "như thế nào "),
            ("mn", "mọi người ")
        ]

        for item in shorthands {
            engine.reset()
            _ = typeString(item.raw)
            let spaceRes = engine.processKey(" ")
            XCTAssertTrue(spaceRes.consumed, "Shorthand \(item.raw) should consume Space and expand")
            XCTAssertEqual(spaceRes.replacementText, item.expected, "Shorthand \(item.raw) failed to expand correctly")
            XCTAssertFalse(engine.previousWordWasEnglish, "Expanding shorthand must not flag previousWordWasEnglish = true")
        }

        // Verify that subsequent word is not biased toward English: "ko car" -> "không cả"
        engine.reset()
        _ = typeString("ko")
        _ = engine.processKey(" ")
        _ = typeString("car")
        let carSpace = engine.processKey(" ")
        // In Vietnamese mode, "car" formats to "cả" and should remain "cả " on space
        let carOutput = carSpace.consumed ? carSpace.replacementText : carSpace.currentWord + " "
        XCTAssertEqual(carOutput, "cả ", "Subsequent word after shorthand must remain in Vietnamese mode")
    }

    // MARK: - R1-BUG-03: dduoc restoration ordering

    func testR1_BUG_03_DduocExpandsToDuocOnSpace() {
        engine.reset()
        _ = typeString("dduoc")
        XCTAssertEqual(engine.formattedWord, "đuoc")
        let spaceRes = engine.processKey(" ")
        XCTAssertTrue(spaceRes.consumed, "Space after 'dduoc' must trigger auto-diacritic expansion")
        XCTAssertEqual(spaceRes.replacementText, "được ", "'dduoc ' must expand to 'được ' instead of raw ASCII")
    }

    // MARK: - R1-BUG-04: Developer keywords (if, of, var)

    func testR1_BUG_04_DeveloperKeywordsDoNotCorrupt() {
        let keywords = ["if", "of", "var"]
        for kw in keywords {
            engine.reset()
            _ = typeString(kw)
            let spaceRes = engine.processKey(" ")
            let finalOutput = spaceRes.consumed ? spaceRes.replacementText : spaceRes.currentWord + " "
            XCTAssertEqual(finalOutput, kw + " ", "Developer keyword '\(kw)' must not corrupt into Vietnamese diacritic")
        }

        // Test with punctuation boundary: "if(" -> "if("
        engine.reset()
        _ = typeString("if")
        let parenRes = engine.processKey("(")
        let parenOutput = parenRes.consumed ? parenRes.replacementText : engine.formattedWord + "("
        XCTAssertEqual(parenOutput, "if(", "Developer keyword 'if(' must restore on punctuation boundary")
    }

    // MARK: - R1-BUG-05: Double-escape collapse with www in URLs

    func testR1_BUG_05_WwwUrlPreserved() {
        let url = "www.google.com"
        let output = fullOutput(for: url)
        XCTAssertEqual(output, "www.google.com", "URL with 'www' prefix must not be truncated to 'ww'")

        let fullUrl = "https://www.google.com"
        let fullOutputResult = fullOutput(for: fullUrl)
        XCTAssertEqual(fullOutputResult, "https://www.google.com", "Full URL with 'www' must be preserved")
    }

    // MARK: - R1-BUG-06: Tone removal key z (Telex) and 0 (VNI) after Backspace

    func testR1_BUG_06_ToneRemovalAfterBackspace() {
        // Telex: toans -> toán, BS -> toá, z -> toa
        engine.inputMethod = .telex
        engine.reset()
        _ = typeString("toans")
        XCTAssertEqual(engine.formattedWord, "toán")

        let bsRes = engine.handleBackspace()
        XCTAssertEqual(bsRes.currentWord, "toá")
        XCTAssertEqual(engine.formattedWord, "toá")

        let zRes = engine.processKey("z")
        XCTAssertTrue(zRes.consumed, "z should be consumed as tone remover after backspace")
        XCTAssertEqual(engine.formattedWord, "toa", "z after backspace on 'toá' must strip the acute tone to 'toa'")

        // VNI: toan1 -> toán, BS -> toá, 0 -> toa
        engine.inputMethod = .vni
        engine.reset()
        _ = typeString("toan1")
        XCTAssertEqual(engine.formattedWord, "toán")

        let bsVni = engine.handleBackspace()
        XCTAssertEqual(bsVni.currentWord, "toá")
        XCTAssertEqual(engine.formattedWord, "toá")

        let zeroRes = engine.processKey("0")
        XCTAssertTrue(zeroRes.consumed, "0 should be consumed as tone remover after backspace in VNI")
        XCTAssertEqual(engine.formattedWord, "toa", "0 after backspace on 'toá' must strip the acute tone to 'toa'")
    }

    // MARK: - R1-BUG-07: VNI open syllables a6 and a8 do not revert on Space

    func testR1_BUG_07_VNIOpenSyllablesDoNotRevertOnSpace() {
        engine.inputMethod = .vni
        let vniCases: [(raw: String, expectedFormatted: String, expectedOnSpace: String)] = [
            ("a6", "â", "â "),
            ("a8", "ă", "ă "),
            ("o7", "ơ", "ơ "),
            ("u7", "ư", "ư ")
        ]

        for item in vniCases {
            engine.reset()
            _ = typeString(item.raw)
            XCTAssertEqual(engine.formattedWord, item.expectedFormatted, "VNI formatting failed for \(item.raw)")

            let spaceRes = engine.processKey(" ")
            let output = spaceRes.consumed ? spaceRes.replacementText : spaceRes.currentWord + " "
            XCTAssertEqual(output, item.expectedOnSpace, "VNI character '\(item.raw)' must not revert to ASCII on Space")
        }
    }

    // MARK: - R1-BUG-08: Triphthong distortion (thuowr -> thuở, huow -> huơ)

    func testR1_BUG_08_ThuorAndHuorOrthography() {
        engine.inputMethod = .telex
        engine.reset()
        _ = typeString("thuowr")
        XCTAssertEqual(engine.formattedWord, "thuở", "thuowr must produce 'thuở' (not 'thưở')")
        let spaceRes = engine.processKey(" ")
        let thuorOutput = spaceRes.consumed ? spaceRes.replacementText : spaceRes.currentWord + " "
        XCTAssertEqual(thuorOutput, "thuở ", "'thuở' must be preserved on Space")

        engine.reset()
        _ = typeString("huow")
        XCTAssertEqual(engine.formattedWord, "huơ", "huow must produce 'huơ' (not 'hươ')")

        // Closed syllable should still use 'ươ': thuowng -> thương
        engine.reset()
        _ = typeString("thuowng")
        XCTAssertEqual(engine.formattedWord, "thương", "Closed syllable 'thuowng' must produce 'thương'")
    }

    // MARK: - R1-BUG-09: Mixed-case dD produces uppercase Đ

    func testR1_BUG_09_MixedCaseDdProducesUppercaseD() {
        engine.inputMethod = .telex

        // d + D -> Đ
        engine.reset()
        _ = engine.processKey("d")
        _ = engine.processKey("D")
        XCTAssertEqual(engine.formattedWord, "Đ", "dD must produce uppercase 'Đ'")

        // D + d -> Đ
        engine.reset()
        _ = engine.processKey("D")
        _ = engine.processKey("d")
        XCTAssertEqual(engine.formattedWord, "Đ", "Dd must produce uppercase 'Đ'")

        // D + D -> Đ
        engine.reset()
        _ = engine.processKey("D")
        _ = engine.processKey("D")
        XCTAssertEqual(engine.formattedWord, "Đ", "DD must produce uppercase 'Đ'")

        // d + d -> đ
        engine.reset()
        _ = engine.processKey("d")
        _ = engine.processKey("d")
        XCTAssertEqual(engine.formattedWord, "đ", "dd must produce lowercase 'đ'")
    }

    // MARK: - R1-BUG-10: Common English words (down, town, door, poor, major)

    func testR1_BUG_10_CommonEnglishWordsDoNotCorrupt() {
        engine.inputMethod = .telex
        let words = ["down", "town", "door", "poor", "major", "floor", "brown", "clown"]
        for w in words {
            engine.reset()
            _ = typeString(w)
            let spaceRes = engine.processKey(" ")
            let output = spaceRes.consumed ? spaceRes.replacementText : spaceRes.currentWord + " "
            XCTAssertEqual(output, w + " ", "English word '\(w)' must not be corrupted to Vietnamese diacritic")
        }
    }
}
