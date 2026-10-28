import XCTest
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

final class VietnameseEngineTests: XCTestCase {
    var engine: VietnameseInputEngine!

    override func setUp() {
        super.setUp()
        engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
    }

    // Helper to simulate keystrokes
    private func typeString(_ str: String) -> EngineResult {
        var lastResult = EngineResult()
        for ch in str {
            lastResult = engine.processKey(ch)
        }
        return lastResult
    }

    // MARK: - Telex Tests

    func testTelexBasicAcute() {
        engine.inputMethod = .telex
        _ = typeString("toans")
        XCTAssertEqual(engine.formattedWord, "toán")
    }

    func testTelexToneModernAndTraditional() {
        engine.inputMethod = .telex
        engine.tonePlacement = .modern
        _ = typeString("hoaf")
        XCTAssertEqual(engine.formattedWord, "hòa")

        engine.reset()
        engine.tonePlacement = .traditional
        _ = typeString("hoaf")
        XCTAssertEqual(engine.formattedWord, "hoà")
    }

    func testTelexComplexDuong() {
        engine.inputMethod = .telex
        _ = typeString("dduwowngf")
        XCTAssertEqual(engine.formattedWord, "đường")
    }

    func testTelexToneRemovalWithZ() {
        engine.inputMethod = .telex
        _ = typeString("toans")
        XCTAssertEqual(engine.formattedWord, "toán")

        let res = engine.processKey("z")
        XCTAssertEqual(engine.formattedWord, "toan")
        XCTAssertTrue(res.consumed)
    }

    func testTelexTiengViet() {
        engine.inputMethod = .telex
        _ = typeString("tieengs")
        XCTAssertEqual(engine.formattedWord, "tiếng")

        engine.reset()
        _ = typeString("vieetj")
        XCTAssertEqual(engine.formattedWord, "việt")
    }

    // MARK: - VNI Tests

    func testVNIBasicAcute() {
        engine.inputMethod = .vni
        _ = typeString("toan1")
        XCTAssertEqual(engine.formattedWord, "toán")
    }

    func testVNIComplexDuong() {
        engine.inputMethod = .vni
        _ = typeString("d9u7o7ng2")
        XCTAssertEqual(engine.formattedWord, "đường")
    }

    func testVNIToneRemovalWithZero() {
        engine.inputMethod = .vni
        _ = typeString("toan1")
        XCTAssertEqual(engine.formattedWord, "toán")

        let res = engine.processKey("0")
        XCTAssertEqual(engine.formattedWord, "toan")
        XCTAssertTrue(res.consumed)
    }

    // MARK: - Auto-English Restore & Real-Time Bilingual Tests

    func testAutoEnglishRestoreWindow() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true
        _ = typeString("window")
        // Real-time phonotactic validation keeps "window" intact even before Space
        XCTAssertEqual(engine.formattedWord, "window")
        let spaceRes = engine.processKey(" ")
        XCTAssertFalse(spaceRes.consumed)
    }

    func testAutoEnglishRestoreSafari() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true
        _ = typeString("safari")
        // Real-time phonotactic validation reverts "sàari" -> "safari" immediately
        XCTAssertEqual(engine.formattedWord, "safari")
    }

    func testAutoEnglishDetectorVocabulary() {
        XCTAssertTrue(SmartEnglishDetector.isEnglishWord("react"))
        XCTAssertTrue(SmartEnglishDetector.isEnglishWord("function"))
        XCTAssertTrue(SmartEnglishDetector.isEnglishWord("window"))
        XCTAssertTrue(SmartEnglishDetector.isEnglishWord("safari"))
        XCTAssertTrue(SmartEnglishDetector.isEnglishWord("status"))
        XCTAssertTrue(SmartEnglishDetector.isEnglishWord("const"))
    }

    func testAutoEnglishRestoreStatus() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true
        _ = typeString("status")
        XCTAssertEqual(engine.formattedWord, "status")
    }

    func testAutoEnglishRestoreConst() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true
        _ = typeString("const")
        XCTAssertEqual(engine.formattedWord, "const")
    }

    func testOnSpaceRestoreForHomographEnglishWords() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true

        // "test" looks like "tét" while typing, then restores to "test " on Space
        _ = typeString("test")
        XCTAssertEqual(engine.formattedWord, "tét")
        let spaceRes = engine.processKey(" ")
        XCTAssertEqual(spaceRes.replacementText, "test ")
        XCTAssertTrue(spaceRes.consumed)

        // "raw" looks like "ră" while typing, then restores to "raw " on Space (open 'ă' is invalid in Vietnamese)
        _ = typeString("raw")
        XCTAssertEqual(engine.formattedWord, "ră")
        let rawSpace = engine.processKey(" ")
        XCTAssertEqual(rawSpace.replacementText, "raw ")
        XCTAssertTrue(rawSpace.consumed)

        // "root" looks like "rôt" while typing, then restores to "root " on Space (untoned stop final '-t' is invalid)
        _ = typeString("root")
        XCTAssertEqual(engine.formattedWord, "rôt")
        let rootSpace = engine.processKey(" ")
        XCTAssertEqual(rootSpace.replacementText, "root ")
        XCTAssertTrue(rootSpace.consumed)
    }

    func testBilingualMixedSentenceVietnameseAndEnglish() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true

        // Simulate typing a full bilingual sentence word by word
        let pairs: [(raw: String, expectedBeforeSpace: String, expectedAfterSpace: String)] = [
            ("xuwr", "xử", "xử"),
            ("lys", "lý", "lý"),
            ("caanf", "cần", "cần"),
            ("hoox", "hỗ", "hỗ"),
            ("trowj", "trợ", "trợ"),
            ("car", "cả", "cả"), // Vietnamese "cả" must NOT turn into English "car" in Vietnamese context!
            ("tieengs", "tiếng", "tiếng"),
            ("anh", "anh", "anh"),
            ("vaf", "và", "và"),
            ("tieengs", "tiếng", "tiếng"),
            ("vieetj", "việt", "việt"),
            ("trong", "trong", "trong"),
            ("project", "project", "project"),
            ("react", "react", "react"),
            ("support", "support", "support"),
            ("feature", "feature", "feature"),
            ("english", "english", "english"),
            ("vietnamese", "vietnamese", "vietnamese"),
            ("world", "world", "world"),
            ("work", "work", "work"),
            ("new", "new", "new"),
            ("view", "view", "view"),
            ("more", "more", "more"),
            ("here", "here", "here"),
            ("user", "user", "user"),
            ("part", "part", "part"),
            ("left", "left", "left"),
            ("next", "next", "next")
        ]

        for item in pairs {
            _ = typeString(item.raw)
            XCTAssertEqual(engine.formattedWord, item.expectedBeforeSpace, "Failed before space for input: \(item.raw)")
            let spaceRes = engine.processKey(" ")
            if spaceRes.consumed {
                XCTAssertEqual(spaceRes.replacementText, item.expectedAfterSpace + " ", "Failed after space for input: \(item.raw)")
            }
        }
    }

    func testContextualEnglishSentenceWithHomographs() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true

        // Typing "hello" sets previousWordWasEnglish = true
        _ = typeString("hello")
        _ = engine.processKey(" ")
        XCTAssertTrue(engine.previousWordWasEnglish)

        // Now typing "car" in an English sentence restores "cả" -> "car " on Space!
        _ = typeString("car")
        let carSpace = engine.processKey(" ")
        XCTAssertEqual(carSpace.replacementText, "car ")
    }

    func testVaWordFastRollAndBackspace() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true

        // 1. Standard "vaf" -> "và"
        _ = typeString("vaf")
        XCTAssertEqual(engine.formattedWord, "và")
        _ = engine.processKey(" ")

        // 2. Fast-roll "vfa" (index finger hits 'f' before pinky hits 'a') -> "và"
        _ = typeString("vfa")
        XCTAssertEqual(engine.formattedWord, "và")

        // 3. Backspace twice on 2-letter word "và" must completely clear the word, then retyping "vaf" -> "và"
        _ = engine.handleBackspace()
        XCTAssertEqual(engine.formattedWord, "v")
        _ = engine.handleBackspace()
        XCTAssertEqual(engine.formattedWord, "")

        _ = typeString("vaf")
        XCTAssertEqual(engine.formattedWord, "và")
    }

    // MARK: - Typo Corrector Tests

    func testTypoToneCorrection() {
        engine.inputMethod = .telex
        // User accidentally types 'f' (grave) then 's' (acute)
        _ = typeString("toanfs")
        XCTAssertEqual(engine.formattedWord, "toán")
    }

    func testHetTextAndKhoogRegression() {
        engine.inputMethod = .telex
        engine.autoEnglishRestore = true

        // 1. "heets" -> "hết" and MUST NOT revert to "heets " on Space!
        _ = typeString("heets")
        XCTAssertEqual(engine.formattedWord, "hết")
        let hetSpace = engine.processKey(" ")
        XCTAssertFalse(hetSpace.consumed, "Vietnamese 'hết' must not be reverted to 'heets' on Space")

        // 2. "text" typed with single 'x' ("text") -> "text"
        _ = typeString("text")
        XCTAssertEqual(engine.formattedWord, "text")
        _ = engine.processKey(" ")

        // 3. "text" typed with double 'xx' Telex escape ("texxt") -> "text"
        _ = typeString("texxt")
        XCTAssertEqual(engine.formattedWord, "text")
        let textSpace = engine.processKey(" ")
        XCTAssertFalse(textSpace.consumed)

        // 4. "khoog" (missed 'n' in "không") -> "không"
        _ = typeString("khoog")
        XCTAssertEqual(engine.formattedWord, "không")
        _ = engine.processKey(" ")

        // 5. "ddwuocj" (fast-roll 'w' before 'u' in "được") -> "được"
        _ = typeString("ddwuocj")
        XCTAssertEqual(engine.formattedWord, "được")
        let duocSpace = engine.processKey(" ")
        XCTAssertFalse(duocSpace.consumed)

        // 6. SuggestionEngine contextual N-gram & typo fixes
        let cands1 = SuggestionEngine.suggest(currentWord: "", rawWord: "", sentenceWords: ["không", "hiển"])
        XCTAssertEqual(cands1.first?.text, "thị")

        let cands2 = SuggestionEngine.suggest(currentWord: "", rawWord: "", sentenceWords: ["chưa", "đạt"])
        XCTAssertEqual(cands2.first?.text, "value")

        let polished = VietnameseTextPolisher.polish("không hiển thị ddwuocj hết text")
        XCTAssertEqual(polished, "không hiển thị được hết text")

        // 7. "ddansh" (free-order 's' before 'h' in "đánh") -> "đánh"
        engine.reset()
        _ = typeString("ddansh")
        XCTAssertEqual(engine.formattedWord, "đánh")
        let danhSpace = engine.processKey(" ")
        XCTAssertFalse(danhSpace.consumed)

        // 8. Auto-Diacritic Restore on Space: "duoc " -> "được ", "khong " -> "không "
        engine.reset()
        _ = typeString("duoc")
        let duocAuto = engine.processKey(" ")
        XCTAssertTrue(duocAuto.consumed)
        XCTAssertEqual(duocAuto.replacementText, "được ")

        // 9. Mid-sentence SuggestionEngine 3-tier ("không  thị duoc| hết text")
        let midSentenceCands = SuggestionEngine.suggest(
            currentWord: "duoc",
            rawWord: "duoc",
            sentenceWords: ["không", "thị"],
            fullSentenceText: "không  thị duoc hết text",
            wordAfterCursor: "hết"
        )
        XCTAssertEqual(midSentenceCands.first?.text, "được")
        XCTAssertTrue(midSentenceCands.contains(where: { $0.kind == .aiPolish && $0.text == "không hiển thị được hết text" }))
    }

    @MainActor
    func testOnDeviceAIEngineAndRefinementGuard() async {
        // 1. Token-Preservation Guard must accept valid diacritic restoration and reject dropped words
        XCTAssertTrue(OnDeviceAIEngine.isValidRefinement(
            base: "toi dang test thu bo go tieng viet moi",
            candidate: "Tôi đang test thử bộ gõ tiếng Việt mới"
        ))
        XCTAssertFalse(OnDeviceAIEngine.isValidRefinement(
            base: "không hiển thị được hết text",
            candidate: "không được hết text"
        ))

        // 2. NSSpellChecker completions work on-device in <1ms
        let enComps = OnDeviceAIEngine.spellCheckerCompletions(partialWord: "sugg", fullSentence: "sugg", limit: 3)
        XCTAssertFalse(enComps.isEmpty)

        // 3. FoundationModels availability & inference check
        if OnDeviceAIEngine.isFoundationModelAvailable {
            let res = await OnDeviceAIEngine.shared.inferSentencePolishAndNextWord(rawSentence: "thực co đang hoạt động tot")
            XCTAssertNotNil(res)
            XCTAssertTrue(res?.polishedSentence.lowercased().contains("hoạt động tốt") == true)

            let res2 = await OnDeviceAIEngine.shared.inferSentencePolishAndNextWord(rawSentence: "toi dang thu go tieng viet không dau")
            XCTAssertNotNil(res2)
            XCTAssertEqual(res2?.polishedSentence.lowercased(), "tôi đang thử gõ tiếng việt không dấu")
        }

        // 4. Synchronous SuggestionEngine check for "toi dang thu go tieng viet không dau"
        let unsignedCands = SuggestionEngine.suggest(
            currentWord: "dau",
            rawWord: "dau",
            sentenceWords: ["toi", "dang", "thu", "go", "tieng", "viet", "không"],
            fullSentenceText: "toi dang thu go tieng viet không dau"
        )
        XCTAssertEqual(unsignedCands.first?.text, "dấu")
        XCTAssertTrue(unsignedCands.contains(where: { $0.kind == .aiPolish && $0.text.lowercased() == "tôi đang thử gõ tiếng việt không dấu" }))

        // 5. Regression test for trailing-space cursor at end of clause ("toi dang thu go tieng viet không dau " at cursor=37)
        let trailingSpaceText = "toi dang thu go tieng viet không dau "
        let nsTrailing = trailingSpaceText as NSString
        let (cStart, cEnd) = EventTapHook.findClauseBounds(in: trailingSpaceText, cursorLocation: nsTrailing.length)
        XCTAssertEqual(cStart, 0)
        XCTAssertEqual(cEnd, 36)
        // Clamped left/right lengths must never be negative when safeCursor (37) > clauseEnd (36)
        let safeCursor = nsTrailing.length
        let leftLen = max(0, safeCursor - cStart)
        let rightLen = max(0, min(nsTrailing.length - safeCursor, cEnd - safeCursor))
        XCTAssertEqual(leftLen, 37)
        XCTAssertEqual(rightLen, 0)
    }

    @MainActor
    func testCustomMacroRegistryAndControlCenterStoreSync() async {
        CustomMacroRegistry.shared.resetToDefaults()

        // 1. Validate error cases
        XCTAssertEqual(CustomMacroRegistry.validate(trigger: "", replacement: "Việt Nam"), .emptyTrigger)
        XCTAssertEqual(CustomMacroRegistry.validate(trigger: "ha noi", replacement: "Hà Nội"), .triggerContainsWhitespace)
        XCTAssertEqual(CustomMacroRegistry.validate(trigger: "hn", replacement: ""), .emptyReplacement)
        XCTAssertEqual(CustomMacroRegistry.validate(trigger: "hn", replacement: "hn"), .identicalTriggerAndReplacement)

        // 2. Add custom macro via store and verify engine expansion
        let store = VFlowControlCenterStore.shared
        store.newMacroTrigger = "hcm"
        store.newMacroReplacement = "Thành phố Hồ Chí Minh"
        store.submitNewMacro()
        XCTAssertNil(store.macroValidationError)
        XCTAssertEqual(CustomMacroRegistry.shared.lookup("hcm"), "Thành phố Hồ Chí Minh")

        // Verify SuggestionEngine surfaces custom macro as Tier 1 teencodeExpansion
        let cands = SuggestionEngine.suggest(
            currentWord: "hcm",
            rawWord: "hcm",
            sentenceWords: ["ở"],
            fullSentenceText: "ở hcm"
        )
        XCTAssertEqual(cands.first?.text, "Thành phố Hồ Chí Minh")
        XCTAssertEqual(cands.first?.kind, .teencodeExpansion)

        // 3. Verify two-way inputMethod sync across Store, EventTapHook, and CaretHUDModel
        store.inputMethod = .vni
        XCTAssertEqual(EventTapHook.shared.engine.inputMethod, .vni)
        XCTAssertEqual(CaretHUDModel.shared.inputMethod, .vni)

        store.syncInputMethodFromExternal(.telex)
        XCTAssertEqual(store.inputMethod, .telex)
        XCTAssertEqual(CaretHUDModel.shared.inputMethod, .telex)

        // Cleanup back to defaults
        CustomMacroRegistry.shared.resetToDefaults()
    }

    func testAryIntervocalicTelexEscapeAndEnglishDoubleConsonants() {
        // 1. Typing "a-r-y" directly outputs "ary" (while "a-y-r" outputs Vietnamese "ảy")
        engine.reset()
        _ = typeString("ary")
        XCTAssertEqual(engine.formattedWord, "ary")
        let arySpace = engine.processKey(" ")
        XCTAssertFalse(arySpace.consumed)

        engine.reset()
        _ = typeString("ayr")
        XCTAssertEqual(engine.formattedWord, "ảy")

        // 2. Typing double-r Telex escape ("arr" -> "ar", "arry" -> "ary", "ayrr" -> "ayr")
        engine.reset()
        _ = typeString("arr")
        XCTAssertEqual(engine.formattedWord, "ar")
        let arrSpace = engine.processKey(" ")
        XCTAssertFalse(arrSpace.consumed)

        engine.reset()
        _ = typeString("arry")
        XCTAssertEqual(engine.formattedWord, "ary")
        let arrySpace = engine.processKey(" ")
        XCTAssertFalse(arrySpace.consumed)

        engine.reset()
        _ = typeString("ayrr")
        XCTAssertEqual(engine.formattedWord, "ayr")

        // 3. Intervocalic tone letters ('s', 'f', 'r', 'x', 'j') between plain vowels stay literal
        let intervocalicWords = ["ary", "ory", "ery", "ury", "are", "use", "base", "safe", "vary", "diary", "binary", "library", "query", "very", "every", "history", "memory"]
        for word in intervocalicWords {
            engine.reset()
            _ = typeString(word)
            XCTAssertEqual(engine.formattedWord, word, "Expected intervocalic word '\(word)' to stay intact, got '\(engine.formattedWord)'")
        }

        // 4. Genuine English double-consonant words ('rr', 'ss', 'ff') keep both letters
        let genuineDoubleWords = ["array", "arrow", "error", "carry", "sorry", "current", "correct", "pass", "class", "coffee", "diff", "off"]
        for word in genuineDoubleWords {
            engine.reset()
            _ = typeString(word)
            XCTAssertEqual(engine.formattedWord, word, "Expected genuine English double-consonant word '\(word)' to stay intact, got '\(engine.formattedWord)'")
        }
    }

    @MainActor
    func testContextualTypoAndSentencePolishSuggestions() async {
        // 1. User's exact screenshot case: "to đang thu go tieng viet không cau"
        let cands = SuggestionEngine.suggest(
            currentWord: "cau",
            rawWord: "cau",
            sentenceWords: ["to", "đang", "thu", "go", "tieng", "viet", "không"],
            fullSentenceText: "to đang thu go tieng viet không cau"
        )
        // Tier 1 (#1) must be "dấu" (contextual typo fix for "không cau"), NOT "cấu hình"
        XCTAssertEqual(cands.first?.text, "dấu")
        XCTAssertEqual(cands.first?.kind, .teencodeExpansion)
        // Tier 2 (#2) must be full-sentence polish "tôi đang thử gõ tiếng Việt không dấu"
        XCTAssertTrue(cands.contains(where: { $0.kind == .aiPolish && $0.text.lowercased() == "tôi đang thử gõ tiếng việt không dấu" }))
        // Tier 3 (#3) must be "câu" (direct diacritic match for "cau")
        XCTAssertTrue(cands.contains(where: { $0.text == "câu" }))

        // 2. Refinement guard allows character-level typo fixes ("to" -> "Tôi", "cau" -> "dấu")
        XCTAssertTrue(OnDeviceAIEngine.isValidRefinement(
            base: "To đang thử gõ tiếng Việt không cau",
            candidate: "Tôi đang thử gõ tiếng Việt không dấu"
        ))

        // 3. On-Device Neural Engine LLM inference for "to đang thu go tieng viet không cau"
        if OnDeviceAIEngine.isFoundationModelAvailable {
            let aiRes = await OnDeviceAIEngine.shared.inferSentencePolishAndNextWord(
                rawSentence: "to đang thu go tieng viet không cau"
            )
            XCTAssertNotNil(aiRes)
            XCTAssertEqual(aiRes?.polishedSentence.lowercased(), "tôi đang thử gõ tiếng việt không dấu")
        }

        // 4. Contextual Vietnamese typo & double-vowel repairs ("thaat sư", "phân suggest", "đúng nghia chuan")
        let p1 = VietnameseTextPolisher.polish("theo như anh thì phân suggest bằng AI thaat sư không tốt lam")
        XCTAssertTrue(p1.lowercased().contains("như ảnh thì phần suggest bằng ai thật sự không tốt lắm"))

        let p2 = VietnameseTextPolisher.polish("khi dung ra nó cần suggest chuan hon khi user co go sai và AI cần suggest lại text đúng nghia chuan")
        XCTAssertTrue(p2.lowercased().contains("khi đúng ra nó cần suggest chuẩn hơn khi user có gõ sai và ai cần suggest lại text đúng nghĩa chuẩn"))
    }

    @MainActor
    func testSystemPromptSeverityAndSecureFieldGuard() async {
        // 1. Verify 3-Level Severity Evaluation (.normal, .moderate, .high)
        XCTAssertEqual(
            SuggestionEngine.evaluateSeverity(rawSentence: "Tôi đang thử gõ tiếng Việt có dấu", preset: .standard),
            .normal
        )
        XCTAssertEqual(
            SuggestionEngine.evaluateSeverity(rawSentence: "Tôi đang thử gõ tiếng Việt có dau", preset: .standard),
            .moderate
        )
        XCTAssertEqual(
            SuggestionEngine.evaluateSeverity(rawSentence: "to đang thu go tieng viet không cau", preset: .standard),
            .high
        )

        // 2. Verify System Prompt compliance raises severity to .high when violated
        XCTAssertEqual(
            SuggestionEngine.evaluateSeverity(rawSentence: "tôi ko biết làm thế nào", preset: .formalEmail),
            .high
        )
        XCTAssertEqual(
            SuggestionEngine.evaluateSeverity(rawSentence: "kiểu như là hôm nay trời đẹp", preset: .concise),
            .high
        )

        // 3. Verify promoteAIPolishOnHighSeverity places full-sentence ✨ AI Polish at index 0 (Tab ⇥)
        let promoted = SuggestionEngine.suggest(
            currentWord: "cau",
            rawWord: "cau",
            sentenceWords: ["to", "đang", "thu", "go", "tieng", "viet", "không"],
            fullSentenceText: "to đang thu go tieng viet không cau",
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(promoted.first?.kind, .aiPolish)
        XCTAssertEqual(promoted.first?.severity, .high)
        XCTAssertEqual(promoted.first?.text.lowercased(), "tôi đang thử gõ tiếng việt không dấu")

        // 4. Verify Password / Secure / Hidden Text Field metadata detection
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: "AXSecureTextField",
            description: nil,
            placeholder: nil,
            value: nil
        ))
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: "Nhập mật khẩu của bạn",
            placeholder: nil,
            value: nil
        ))
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: nil,
            placeholder: "Enter password",
            value: nil
        ))
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: nil,
            placeholder: nil,
            value: "••••••••"
        ))
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: nil,
            placeholder: nil,
            value: "******"
        ))
        XCTAssertTrue(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: nil,
            placeholder: nil,
            value: "normal",
            isSystemSecureInput: true
        ))
        XCTAssertFalse(AccessibilityBridge.isSecureFieldMetadata(
            role: "AXTextField",
            subrole: nil,
            description: "Ghi chú công việc",
            placeholder: "Nhập văn bản...",
            value: "Xin chào Việt Nam"
        ))
    }
}
