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

    @MainActor
    func testMouseClickHUDHitTestAndCustomDoubleTabShortcuts() async {
        // 1. User's screenshot case: "không can thiet phải nhu the"
        let polishedScreenshot = VietnameseTextPolisher.polish("không can thiet phải nhu the")
        XCTAssertEqual(polishedScreenshot.lowercased(), "không cần thiết phải như thế")

        let screenshotSeverity = SuggestionEngine.evaluateSeverity(
            rawSentence: "không can thiet phải nhu the",
            preset: .standard
        )
        XCTAssertEqual(screenshotSeverity, .high)

        let screenshotSuggestions = SuggestionEngine.suggest(
            currentWord: "the",
            rawWord: "the",
            sentenceWords: ["không", "can", "thiet", "phải", "nhu"],
            fullSentenceText: "không can thiet phải nhu the",
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(screenshotSuggestions.first?.kind, .aiPolish)
        XCTAssertEqual(screenshotSuggestions.first?.severity, .high)
        XCTAssertEqual(screenshotSuggestions.first?.text.lowercased(), "không cần thiết phải như thế")

        // 2. Verify CaretHUDModel mouse click hit-testing (dispatchHitTest) on suggestion chips & buttons
        let hud = CaretHUDModel.shared
        hud.suggestions = [
            SuggestionItem(text: "Không cần thiết phải như thế", kind: .aiPolish, replaceCurrentWord: false, severity: .high),
            SuggestionItem(text: "thế", kind: .teencodeExpansion, replaceCurrentWord: true, targetWordToReplace: "the", severity: .high)
        ]
        hud.chipFrames = [
            0: CGRect(x: 112, y: 8, width: 220, height: 34),
            1: CGRect(x: 340, y: 8, width: 70, height: 34)
        ]
        hud.modeButtonFrame = CGRect(x: 64, y: 10, width: 42, height: 28)

        let clickExpectation = expectation(description: "Mouse click on HUD suggestion chip #1")
        var clickedItem: SuggestionItem?
        hud.onSelectSuggestion = { item in
            clickedItem = item
            clickExpectation.fulfill()
        }

        let handled = hud.dispatchHitTest(at: CGPoint(x: 180, y: 24), windowSize: CGSize(width: 520, height: 52))
        XCTAssertTrue(handled)
        await fulfillment(of: [clickExpectation], timeout: 1.0)
        XCTAssertEqual(clickedItem?.text, "Không cần thiết phải như thế")

        // 3. Verify Customizable Suggestion Accept Shortcut modes (.doubleTab, .singleTab, .rightArrow, .shiftReturn, .optionNumbers)
        let hook = EventTapHook()
        var selectedShortcutIndex: Int?
        var armedState: Bool = false
        hook.hasActiveSuggestions = { true }
        hook.onSelectSuggestionShortcut = { idx in
            MainActor.assumeIsolated {
                selectedShortcutIndex = idx
            }
            return true
        }
        hook.onDoubleTabArmedChanged = { isArmed in
            MainActor.assumeIsolated {
                armedState = isArmed
            }
        }

        // 3A. Double-Tab (.doubleTab = ⇥⇥): 1st Tab arms, 2nd Tab within 500ms selects Slot #1 (index 0)
        hook.suggestionAcceptShortcut = .doubleTab
        selectedShortcutIndex = nil
        let firstTabConsumed = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_Tab,
            flags: [],
            replaySingleTabOnTimeout: false
        )
        XCTAssertTrue(firstTabConsumed, "1st Tab in Double-Tab mode must be swallowed to keep focus inside active input")
        XCTAssertTrue(armedState, "1st Tab must arm Double-Tab indicator")
        XCTAssertNil(selectedShortcutIndex, "1st Tab alone must not trigger suggestion selection yet")

        let secondTabConsumed = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_Tab,
            flags: [],
            replaySingleTabOnTimeout: false
        )
        XCTAssertTrue(secondTabConsumed, "2nd Tab in Double-Tab mode must be consumed")
        XCTAssertFalse(armedState, "2nd Tab must disarm Double-Tab indicator")
        XCTAssertEqual(selectedShortcutIndex, 0, "2nd Tab must immediately select Suggestion #1 (index 0)")

        // 3B. Single-Tab (.singleTab = ⇥): 1st Tab immediately selects Slot #1 (index 0)
        hook.suggestionAcceptShortcut = .singleTab
        selectedShortcutIndex = nil
        let singleTabConsumed = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_Tab,
            flags: [],
            replaySingleTabOnTimeout: false
        )
        XCTAssertTrue(singleTabConsumed)
        XCTAssertEqual(selectedShortcutIndex, 0)

        // 3C. Right Arrow (.rightArrow = →): 0x7C immediately selects Slot #1 (index 0)
        hook.suggestionAcceptShortcut = .rightArrow
        selectedShortcutIndex = nil
        let arrowConsumed = hook.handleSuggestionShortcutKeyDown(
            keycode: 0x7C,
            flags: [],
            replaySingleTabOnTimeout: false
        )
        XCTAssertTrue(arrowConsumed)
        XCTAssertEqual(selectedShortcutIndex, 0)

        // 3D. Shift + Return (.shiftReturn = ⇧↩): Return with .maskShift selects Slot #1
        hook.suggestionAcceptShortcut = .shiftReturn
        selectedShortcutIndex = nil
        let shiftReturnConsumed = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_Return,
            flags: .maskShift,
            replaySingleTabOnTimeout: false
        )
        XCTAssertTrue(shiftReturnConsumed)
        XCTAssertEqual(selectedShortcutIndex, 0)

        // 3E. Option + 2 (⌥2) works in all modes
        hook.suggestionAcceptShortcut = .optionNumbers
        selectedShortcutIndex = nil
        let opt2Consumed = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_ANSI_2,
            flags: .maskAlternate,
            replaySingleTabOnTimeout: false
        )
        XCTAssertTrue(opt2Consumed)
        XCTAssertEqual(selectedShortcutIndex, 1)
    }

    @MainActor
    func testLongSentenceShiftedSpaceAndFullSentencePolish() {
        // 1. Exact sentence from user's screenshot: "tính ra nó đan gkhoong bị loi nua y ma no chang ra sao"
        let rawScreenshotSentence = "tính ra nó đan gkhoong bị loi nua y ma no chang ra sao"
        let polished = VietnameseTextPolisher.polish(rawScreenshotSentence)
        XCTAssertEqual(
            polished.lowercased(),
            "tính ra nó đang không bị lỗi nữa ý mà nó chẳng ra sao"
        )

        // Verify SuggestionEngine places full-sentence .aiPolish at Slot #1 (#0) with .high severity
        // both while composing the last word and after pressing Space (currentWord == "")
        let sentenceWords = ["tính", "ra", "nó", "đan", "gkhoong", "bị", "loi", "nua", "y", "ma", "no", "chang", "ra", "sao"]
        let afterSpaceSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: sentenceWords,
            fullSentenceText: rawScreenshotSentence,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(afterSpaceSuggestions.first?.kind, .aiPolish)
        XCTAssertEqual(afterSpaceSuggestions.first?.severity, .high)
        XCTAssertEqual(
            afterSpaceSuggestions.first?.text.lowercased(),
            "tính ra nó đang không bị lỗi nữa ý mà nó chẳng ra sao"
        )

        // Verify OnDeviceAIEngine.isValidRefinement accepts LLM candidate when shifted-space "đan gkhoong" -> "đang không"
        XCTAssertTrue(
            OnDeviceAIEngine.isValidRefinement(
                base: rawScreenshotSentence,
                candidate: "Tính ra nó đang không bị lỗi nữa ý mà nó chẳng ra sao"
            )
        )

        // 2. Verify sentences longer than 16 words (up to 48 words) still produce full-sentence .aiPolish suggestions
        let long22WordRaw = "tôi gõ ca 1 cau kha dai nhung lai khong du phần suggest cho toan bộ giao dien cua he thong phan mem"
        let longWords = long22WordRaw.components(separatedBy: " ")
        XCTAssertGreaterThan(longWords.count, 16)
        let longSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: longWords,
            fullSentenceText: long22WordRaw,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(longSuggestions.first?.kind, .aiPolish)
        XCTAssertEqual(
            longSuggestions.first?.text.lowercased(),
            "tôi gõ cả 1 câu khá dài nhưng lại không đủ phần suggest cho toàn bộ giao diện của hệ thống phần mềm"
        )

        // Verify CaretHUDModel.visibleSuggestions dedicates full width to a single chip when .aiPolish > 26 chars
        let hud = CaretHUDModel.shared
        hud.suggestions = longSuggestions
        XCTAssertEqual(hud.visibleSuggestions.count, 1)
        XCTAssertEqual(hud.visibleSuggestions.first?.kind, .aiPolish)

        // 3. Verify TypingBuffer.popLastWord() trims 1 character at a time instead of dropping a whole word per Backspace
        let buf = TypingBuffer()
        buf.appendWord("chẳng")
        buf.appendWord("ra")
        buf.appendWord("sao")
        buf.popLastWord()
        XCTAssertEqual(buf.currentSentence(), "chẳng ra sa")
        buf.popLastWord()
        XCTAssertEqual(buf.currentSentence(), "chẳng ra s")
        buf.popLastWord()
        XCTAssertEqual(buf.currentSentence(), "chẳng ra")
    }

    func testBilingualEnglishAndVietnameseGrammarChecking() {
        // 1. English Grammar: Past-time tense agreement + 3rd-person negative + article a/an
        let enRaw1 = "he go to school yesterday and he dont know a answer"
        let enPolished1 = VietnameseTextPolisher.polish(enRaw1)
        XCTAssertEqual(enPolished1, "He went to school yesterday and he doesn't know an answer")

        let enSug1 = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: enRaw1.components(separatedBy: " "),
            fullSentenceText: enRaw1,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(enSug1.first?.kind, .aiPolish)
        XCTAssertEqual(enSug1.first?.severity, .high)
        XCTAssertEqual(enSug1.first?.text, "He went to school yesterday and he doesn't know an answer")

        // 2. English Grammar: Auxiliary/Perfect verb forms + double comparative + uncountable noun
        let enRaw2 = "i did not went there because i have saw more better informations"
        let enPolished2 = VietnameseTextPolisher.polish(enRaw2)
        XCTAssertEqual(enPolished2, "I did not go there because I have seen better information")

        // 3. OnDeviceAIEngine.isValidRefinement accepts English irregular verb conjugations
        XCTAssertTrue(
            OnDeviceAIEngine.isValidRefinement(
                base: "he go to school yesterday",
                candidate: "He went to school yesterday"
            )
        )

        // 4. Vietnamese Grammar & Orthography: duplicate function words, ng/ngh, g/gh, dành/giành, xử/sử, hỏi/ngã
        let vnRaw = "tôi đang đang suy ngĩ về nghành công ngệ và muốn dành giải thưởng cũng như sử lý các lỗi ngử pháp"
        let vnPolished = VietnameseTextPolisher.polish(vnRaw)
        XCTAssertEqual(
            vnPolished.lowercased(),
            "tôi đang suy nghĩ về ngành công nghệ và muốn giành giải thưởng cũng như xử lý các lỗi ngữ pháp"
        )

        let vnSug = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: vnRaw.components(separatedBy: " "),
            fullSentenceText: vnRaw,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(vnSug.first?.kind, .aiPolish)
        XCTAssertEqual(vnSug.first?.severity, .high)
        XCTAssertEqual(
            vnSug.first?.text.lowercased(),
            "tôi đang suy nghĩ về ngành công nghệ và muốn giành giải thưởng cũng như xử lý các lỗi ngữ pháp"
        )

        XCTAssertTrue(
            OnDeviceAIEngine.isValidRefinement(
                base: vnRaw,
                candidate: vnPolished
            )
        )
    }

    @MainActor
    func testMultiSentencePeriodAndLongParagraph2TierCardSuggestions() async {
        // 1. User's exact scenario: typing '.' mid-sentence ("Hỗ trợ kiểm tra cả ngữ pháp . cho english và tiếng việt.")
        // must NOT break or drop the first clause before '.'
        let userPeriodInput = "Hỗ trợ kiểm tra cả ngữ pháp . cho english và tiếng việt."
        let polishedPeriod = VietnameseTextPolisher.polish(userPeriodInput)
        XCTAssertEqual(polishedPeriod, "Hỗ trợ kiểm tra cả ngữ pháp. Cho English và tiếng Việt.")

        let periodSug = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: userPeriodInput.components(separatedBy: " "),
            fullSentenceText: userPeriodInput,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertEqual(periodSug.first?.kind, .aiPolish)
        XCTAssertEqual(periodSug.first?.text, "Hỗ trợ kiểm tra cả ngữ pháp. Cho English và tiếng Việt.")

        // 2. TypingBuffer preserves words across '.' punctuation and across multi-sentence liveText sync
        let buf = TypingBuffer()
        buf.appendWord("Hỗ")
        buf.appendWord("trợ")
        buf.appendWord("kiểm")
        buf.appendWord("tra")
        buf.appendWord("ngữ")
        buf.appendWord("pháp")
        buf.appendPunctuation(".")
        buf.appendWord("cho")
        buf.appendWord("english")
        XCTAssertEqual(buf.currentSentence(), "Hỗ trợ kiểm tra ngữ pháp. cho english")

        buf.syncWithLiveText("Câu đầu tiên đã xong. câu thu hai van duoc giu nguyen", currentComposingWord: "nguyen")
        XCTAssertEqual(buf.currentSentence(), "Câu đầu tiên đã xong. câu thu hai van duoc giu")

        // 3. Multi-sentence + multi-paragraph (\n) mixed Vietnamese & English full-box polishing
        let multiParaRaw = "tôi đan gkhoong hiểu sao phần mềm bị loi. he go to school yesterday and dont know a answer.\ndòng thứ hai cung can duoc sua chính tả toan bo"
        let multiParaPolished = VietnameseTextPolisher.polish(multiParaRaw)
        XCTAssertTrue(multiParaPolished.contains("Tôi đang không hiểu sao phần mềm bị lỗi."))
        XCTAssertTrue(multiParaPolished.contains("He went to school yesterday and doesn't know an answer."))
        XCTAssertTrue(multiParaPolished.contains("\nDòng thứ hai cũng cần được sửa chính tả toàn bộ"))

        // 4. Verify 2-Tier Card diff counter, line estimation, and 2D hit-testing
        let changedCount = CaretPillView.countChangedWords(raw: userPeriodInput, polished: polishedPeriod)
        XCTAssertGreaterThanOrEqual(changedCount, 3)
        XCTAssertGreaterThanOrEqual(CaretPillView.estimatedLineCount(for: multiParaPolished), 3)

        let hud = CaretHUDModel.shared
        let longItem = SuggestionItem(
            text: multiParaPolished,
            kind: .aiPolish,
            replaceCurrentWord: false,
            severity: .high
        )
        hud.suggestions = [longItem]

        let cardClickExp = expectation(description: "Click on Tier 2 scrollable card area selects full-text suggestion")
        var selectedFromCard: SuggestionItem?
        hud.onSelectSuggestion = { item in
            selectedFromCard = item
            cardClickExp.fulfill()
        }

        // Simulate clicking inside Tier 2 (y = 82) of the 2-Tier Card (width: 560, height: 148)
        let cardHandled = hud.dispatchHitTest(
            at: CGPoint(x: 240, y: 82),
            windowSize: CGSize(width: 560, height: 148)
        )
        XCTAssertTrue(cardHandled)
        await fulfillment(of: [cardClickExp], timeout: 1.0)
        XCTAssertEqual(selectedFromCard?.text, multiParaPolished)

        // 5. Verify 2-Stage Visual Feedback Animation on Tab-Tab / Suggestion Accept ("✨ Đang sửa văn bản..." -> "✓ Đã sửa văn bản")
        hud.triggerSuggestionAcceptFeedback(for: longItem, caretFrame: CGRect(x: 300, y: 300, width: 460, height: 52))
        XCTAssertTrue(hud.isApplyingSuggestion)
        XCTAssertFalse(hud.isSuggestionAppliedSuccess)
        XCTAssertEqual(hud.state, .working)
        XCTAssertTrue(hud.appliedSuggestionText.contains("Tôi đang không hiểu sao phần mềm bị lỗi."))

        // Synchronous notifyTypingState() from applySuggestion during Stage 1 must NOT wipe out the active rewrite animation
        hud.updateOnTyping(
            currentWord: "",
            rawWord: "",
            sentenceWords: ["Tôi", "đang"],
            inputMethod: .telex,
            caretFrame: CGRect(x: 300, y: 300, width: 460, height: 52),
            fullSentenceText: multiParaPolished
        )
        XCTAssertTrue(hud.isApplyingSuggestion)
        XCTAssertEqual(hud.state, .working)

        // After ~320ms, Stage 1 transitions to Stage 2 ("✓ Đã sửa văn bản" Emerald confirmation)
        try? await Task.sleep(nanoseconds: 340_000_000)
        XCTAssertFalse(hud.isApplyingSuggestion)
        XCTAssertTrue(hud.isSuggestionAppliedSuccess)
        XCTAssertEqual(hud.state, .done)

        // 6. Verify clicking a single .aiPolish suggestion succeeds even if windowSize.height == 52 or stale chipFrames existed previously
        hud.chipFrames = [0: CGRect(x: 112, y: 8, width: 45, height: 30)]
        hud.suggestions = [longItem] // didSet must clear stale chipFrames
        XCTAssertTrue(hud.chipFrames.isEmpty, "Updating suggestions must clear stale chipFrames")

        let compactClickExp = expectation(description: "Click on single .aiPolish suggestion at height 52 selects it")
        var selectedCompact: SuggestionItem?
        hud.onSelectSuggestion = { item in
            selectedCompact = item
            compactClickExp.fulfill()
        }
        let compactHandled = hud.dispatchHitTest(
            at: CGPoint(x: 260, y: 24),
            windowSize: CGSize(width: 520, height: 52)
        )
        XCTAssertTrue(compactHandled)
        await fulfillment(of: [compactClickExp], timeout: 1.0)
        XCTAssertEqual(selectedCompact?.text, multiParaPolished)

        // 7. Verify Double-Tab (⇥⇥) accepts 2nd Tab after 550ms (> old 380ms timeout) without losing armed state
        let hook = EventTapHook()
        var shortcutAcceptedIndex: Int?
        hook.hasActiveSuggestions = { true }
        hook.suggestionAcceptShortcut = .doubleTab
        hook.onSelectSuggestionShortcut = { idx in
            MainActor.assumeIsolated {
                shortcutAcceptedIndex = idx
            }
            return true
        }
        let tab1 = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_Tab,
            flags: [],
            replaySingleTabOnTimeout: true
        )
        XCTAssertTrue(tab1)
        try? await Task.sleep(nanoseconds: 550_000_000)
        let tab2 = hook.handleSuggestionShortcutKeyDown(
            keycode: KeyCodeMap.kVK_Tab,
            flags: [],
            replaySingleTabOnTimeout: true
        )
        XCTAssertTrue(tab2)
        XCTAssertEqual(shortcutAcceptedIndex, 0)

        // 8. Verify Browser non-editable elements (AXWebArea, AXLink, AXButton, AXGroup) are rejected
        // while real text inputs (AXTextField, AXTextArea, contenteditable) are accepted
        XCTAssertFalse(AccessibilityBridge.isEditableElementMetadata(role: "AXWebArea"))
        XCTAssertFalse(AccessibilityBridge.isEditableElementMetadata(role: "AXLink"))
        XCTAssertFalse(AccessibilityBridge.isEditableElementMetadata(role: "AXButton"))
        XCTAssertFalse(AccessibilityBridge.isEditableElementMetadata(role: "AXWindow"))
        XCTAssertFalse(AccessibilityBridge.isEditableElementMetadata(role: "AXGroup", isValueSettable: false))
        XCTAssertTrue(AccessibilityBridge.isEditableElementMetadata(role: "AXTextField"))
        XCTAssertTrue(AccessibilityBridge.isEditableElementMetadata(role: "AXTextArea"))
        XCTAssertTrue(AccessibilityBridge.isEditableElementMetadata(role: "AXGroup", isEditableAttr: true))
        XCTAssertTrue(AccessibilityBridge.isEditableElementMetadata(role: "AXStaticText", ancestorIsEditable: true))

        // 9. Verify CaretHUDModel.updateOnTyping hides HUD when text and suggestions are empty (no "Đang gõ văn bản..." phantom pill)
        hud.isApplyingSuggestion = false
        hud.isSuggestionAppliedSuccess = false
        hud.updateOnTyping(
            currentWord: "",
            rawWord: "",
            sentenceWords: [],
            inputMethod: .telex,
            caretFrame: CGRect(x: 200, y: 200, width: 460, height: 52),
            fullSentenceText: ""
        )
        XCTAssertFalse(CaretPillWindow.shared.isVisible)
    }

    @MainActor
    func testKeylogSuggestionVerificationScenario() {
        // 1. Contextual accented Vietnamese typo disambiguation ("cải tiếng" -> "cải tiến", "ổn địng" -> "ổn định")
        XCTAssertEqual(
            SuggestionEngine.resolveContextualWordFix(prevWord: "cải", currentWord: "tiếng"),
            "tiến"
        )
        XCTAssertEqual(
            SuggestionEngine.resolveContextualWordFix(prevWord: "ổn", currentWord: "địng"),
            "định"
        )
        XCTAssertEqual(
            SuggestionEngine.resolveContextualWordFix(prevWord: "tra", currentWord: "fia", wordAfterCursor: "lỗi"),
            "fix"
        )
        XCTAssertEqual(
            VietnameseTextPolisher.polish("vấn đề ngữ cảnh cần cải tiếng."),
            "vấn đề ngữ cảnh cần cải tiến."
        )

        // 2. Full-sentence contextual sliding-window repair on user's keylog sentence:
        // "Grill-me kiểm tra fia lỗi suggestion bị lỗi không nhận ổn địng"
        let rawKeylogSentence = "Grill-me kiểm tra fia lỗi suggestion bị lỗi không nhận ổn địng"
        let polishedKeylogSentence = VietnameseTextPolisher.polish(rawKeylogSentence)
        XCTAssertEqual(
            polishedKeylogSentence,
            "Grill-me kiểm tra fix lỗi suggestion không nhận ổn định"
        )

        // 3. Screenshot scenario ("Grill-me kiểm tra fix lỗi suggestion bị lỗi không nhận ổn định cập nhật"):
        // Must NEVER suggest duplicate "[⇥⇥ cập nhật]" when sentence already ends with "cập nhật",
        // and MUST offer full-sentence contextual rewrite + next-word collocations after "cập nhật"
        let screenshotSentence = "Grill-me kiểm tra fix lỗi suggestion bị lỗi không nhận ổn định cập nhật"
        let screenshotWords = screenshotSentence.components(separatedBy: " ")
        let postUpdateSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: screenshotWords,
            fullSentenceText: screenshotSentence,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertFalse(
            postUpdateSuggestions.contains(where: { $0.text.lowercased() == "cập nhật" }),
            "Must never re-suggest 'cập nhật' when the sentence already ends with 'cập nhật'"
        )
        XCTAssertTrue(
            postUpdateSuggestions.contains(where: {
                $0.kind == .aiPolish &&
                $0.text == "Grill-me kiểm tra fix lỗi suggestion cập nhật không ổn định"
            }),
            "Expected contextual full-sentence rewrite, got: \(postUpdateSuggestions.map(\.text))"
        )

        // Also when cursor is touching the end of "nhật" (currentWord = "nhật", sentenceWords ending with "cập"):
        let touchingNhatSuggestions = SuggestionEngine.suggest(
            currentWord: "nhật",
            rawWord: "nhaatj",
            sentenceWords: Array(screenshotWords.dropLast()),
            fullSentenceText: screenshotSentence,
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertFalse(
            touchingNhatSuggestions.contains(where: { $0.text.lowercased() == "cập nhật" }),
            "Must not suggest 'cập nhật' when 'cập nhật' is already completed at the cursor"
        )

        // 4. User's '/grill-me kịch verify lỗi suggestion' scenario:
        // - After typing "kịch ", suggest "bản" ("kịch bản")
        let afterKichSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: ["kịch"],
            fullSentenceText: "kịch"
        )
        XCTAssertEqual(afterKichSuggestions.first?.text, "bản")

        // - Full sentence "kịch verify lỗi suggestion" & "kịch veriaay lỗi suggestion" polish to "kịch bản verify lỗi suggestion"
        XCTAssertEqual(
            VietnameseTextPolisher.polish("kịch verify lỗi suggestion"),
            "kịch bản verify lỗi suggestion"
        )
        XCTAssertEqual(
            VietnameseTextPolisher.polish("kịch veriaay lỗi suggestion"),
            "kịch bản verify lỗi suggestion"
        )

        // 5. Real-time Telex English typing for "verify" (both direct 'verify' and UniKey double-R escape 'verrify'),
        // plus "service", "version", "target", "cursor"
        let engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
        for ch in "verify" {
            _ = engine.processKey(ch)
        }
        XCTAssertEqual(engine.formattedWord, "verify")
        engine.reset()

        for ch in "verrify" {
            _ = engine.processKey(ch)
        }
        XCTAssertEqual(engine.formattedWord, "verify")
        engine.reset()

        for word in ["service", "version", "target", "cursor"] {
            for ch in word {
                _ = engine.processKey(ch)
            }
            XCTAssertEqual(engine.formattedWord, word)
            engine.reset()
        }
    }

    @MainActor
    func testVoiceDictationAutoStopOnSilenceAndCaretHUDClick() async {
        // 1. Verify VoiceDictationService autoStopOnSilence is enabled by default with ~2.2s silence timeout
        let service = VoiceDictationService.shared
        XCTAssertTrue(service.autoStopOnSilence)
        XCTAssertEqual(service.silenceTimeoutSeconds, 2.2, accuracy: 0.05)

        // 2. Verify ASR spoken error repairs & written AI refinement on real voice log utterances
        let rawVoice1 = "Tôi đang kiểm tra cái phần năng tự lắng nghe xem nó nhận chưa"
        let polishedVoice1 = VietnameseTextPolisher.polish(rawVoice1)
        XCTAssertEqual(polishedVoice1, "Tôi đang kiểm tra cái tính năng tự lắng nghe xem nó nhận chưa")
        let refinedVoice1 = VietnameseTextPolisher.polishVoiceRefinement(rawVoice1)
        XCTAssertEqual(refinedVoice1, "Tôi đang kiểm tra tính năng tự lắng nghe xem nó nhận chưa")

        let rawVoice2 = "Hình như là sau khi anh nhận diện cái phần giọng nói sang nhưng mà đúng ra đến có 1 thao tác AI"
        let polishedVoice2 = VietnameseTextPolisher.polish(rawVoice2)
        XCTAssertEqual(polishedVoice2, "Hình như là sau khi nhận diện cái phần giọng nói sang text nhưng mà đúng ra cần có 1 thao tác AI")
        let refinedVoice2 = VietnameseTextPolisher.polishVoiceRefinement(rawVoice2)
        XCTAssertEqual(refinedVoice2, "Hình như sau khi nhận diện phần giọng nói sang text nhưng đúng ra cần có một thao tác AI")

        // 3. Verify clicking Caret Pill HUD while in Voice Recording (.working) state triggers onStopVoiceRecording
        let hud = CaretHUDModel.shared
        var didTriggerStopVoice = false
        hud.onStopVoiceRecording = {
            didTriggerStopVoice = true
        }
        hud.presentVoiceRecording(
            displayText: "🎙 Đang nghe (VI)... Tôi đang xác nhận xem",
            audioLevel: 0.65,
            caretFrame: CGRect(x: 400, y: 400, width: 460, height: 52)
        )
        XCTAssertEqual(hud.state, .working)
        let handled = hud.dispatchHitTest(at: CGPoint(x: 220, y: 24), windowSize: CGSize(width: 460, height: 52))
        XCTAssertTrue(handled)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(didTriggerStopVoice)

        // 4. Verify presentVoiceCompleted immediately surfaces ✨ AI Polish suggestion on the Caret Pill HUD
        hud.presentVoiceCompleted(
            polishedText: polishedVoice2,
            rawVoiceText: rawVoice2,
            caretFrame: CGRect(x: 400, y: 400, width: 460, height: 52)
        )
        XCTAssertTrue(hud.suggestions.contains(where: { $0.kind == .aiPolish && $0.text == refinedVoice2 }))
        hud.hideHUD()
    }
}
