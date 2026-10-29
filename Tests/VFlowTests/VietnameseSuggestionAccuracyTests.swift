import XCTest
@testable import VFlowCore

final class VietnameseSuggestionAccuracyTests: XCTestCase {

    // MARK: - 1. Target Sentence Polish Verification
    func testCahSuDungDayLaGi_Polish_ProducesCorrectVietnamese() {
        let raw = "cah su dung day la gi"
        let polished = VietnameseTextPolisher.polish(raw)
        XCTAssertEqual(
            polished,
            "cách sử dụng đây là gì",
            "Expected 'cah su dung day la gi' to polish to 'cách sử dụng đây là gì', but got '\(polished)'"
        )

        let capitalizedRaw = "Cah su dung day la gi"
        let capitalizedPolished = VietnameseTextPolisher.polish(capitalizedRaw)
        XCTAssertEqual(
            capitalizedPolished,
            "Cách sử dụng đây là gì",
            "Expected 'Cah su dung day la gi' to polish to 'Cách sử dụng đây là gì', but got '\(capitalizedPolished)'"
        )
    }

    // MARK: - 2. SuggestionEngine Slot 0 / Slot 1 Promotion Verification
    func testCahSuDungDayLaGi_SuggestionEngine_PromotesToSlot0OrSlot1() {
        // High severity promotion: Slot 0 must receive full polished sentence
        let promotedSuggestions = SuggestionEngine.suggest(
            currentWord: "gi",
            rawWord: "gi",
            sentenceWords: ["cah", "su", "dung", "day", "la"],
            fullSentenceText: "cah su dung day la gi",
            promoteAIPolishOnHighSeverity: true
        )

        XCTAssertFalse(promotedSuggestions.isEmpty, "Suggestions list must not be empty")
        XCTAssertEqual(
            promotedSuggestions.first?.kind,
            .aiPolish,
            "When promoteAIPolishOnHighSeverity is true, Slot 0 must be .aiPolish"
        )
        XCTAssertEqual(
            promotedSuggestions.first?.text,
            "cách sử dụng đây là gì",
            "Slot 0 suggestion must be 'cách sử dụng đây là gì'"
        )

        // Without forced promotion: Slot 0 is instant word fix ("gì") and Slot 1 is full sentence polish
        let defaultSuggestions = SuggestionEngine.suggest(
            currentWord: "gi",
            rawWord: "gi",
            sentenceWords: ["cah", "su", "dung", "day", "la"],
            fullSentenceText: "cah su dung day la gi",
            promoteAIPolishOnHighSeverity: false
        )

        XCTAssertGreaterThanOrEqual(defaultSuggestions.count, 2, "Must produce at least 2 suggestions")
        XCTAssertEqual(
            defaultSuggestions[0].kind,
            .teencodeExpansion,
            "Slot 0 should be word fix for 'gi'"
        )
        XCTAssertEqual(
            defaultSuggestions[0].text,
            "gì"
        )
        XCTAssertEqual(
            defaultSuggestions[1].kind,
            .aiPolish,
            "Slot 1 should be full-sentence .aiPolish"
        )
        XCTAssertEqual(
            defaultSuggestions[1].text,
            "cách sử dụng đây là gì"
        )

        // Cursor at end of sentence after trailing space
        let afterSpaceSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: ["cah", "su", "dung", "day", "la", "gi"],
            fullSentenceText: "cah su dung day la gi",
            promoteAIPolishOnHighSeverity: true
        )

        XCTAssertEqual(
            afterSpaceSuggestions.first?.kind,
            .aiPolish
        )
        XCTAssertEqual(
            afterSpaceSuggestions.first?.text,
            "cách sử dụng đây là gì"
        )
    }

    // MARK: - 3. Common Typo & Unaccented Token Fixes
    func testCommonTypoAndUnaccentedTokens() {
        XCTAssertEqual(SuggestionEngine.instantWordFixes["cah"], "cách")
        XCTAssertEqual(SuggestionEngine.instantWordFixes["cach"], "cách")
        XCTAssertEqual(SuggestionEngine.instantWordFixes["day"], "đây")
        XCTAssertEqual(SuggestionEngine.instantWordFixes["la"], "là")
        XCTAssertEqual(SuggestionEngine.instantWordFixes["gi"], "gì")
        XCTAssertEqual(SuggestionEngine.instantWordFixes["su"], "sử")
        XCTAssertEqual(SuggestionEngine.instantWordFixes["dung"], "dụng")

        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["cah"], "cách")
        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["cach"], "cách")
        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["day"], "đây")
        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["la"], "là")
        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["gi"], "gì")
        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["su"], "sử")
        XCTAssertEqual(VietnameseTextPolisher.typoTokenFixes["dung"], "dụng")

        XCTAssertEqual(VietnameseTextPolisher.polish("cah dung day"), "cách dụng đây")
        XCTAssertEqual(VietnameseTextPolisher.polish("day la gi"), "đây là gì")
        XCTAssertEqual(VietnameseTextPolisher.polish("su dung"), "sử dụng")
    }

    // MARK: - 4. Compound Phrase Repairs & Orthographic Preservation
    func testCompoundPhraseRepairsAndOrthographicPreservation() {
        XCTAssertEqual(VietnameseTextPolisher.polish("cah su dung"), "cách sử dụng")
        XCTAssertEqual(VietnameseTextPolisher.polish("cach su dung"), "cách sử dụng")
        XCTAssertEqual(VietnameseTextPolisher.polish("su dung"), "sử dụng")
        XCTAssertEqual(VietnameseTextPolisher.polish("sử dung"), "sử dụng")
        XCTAssertEqual(VietnameseTextPolisher.polish("su dụng"), "sử dụng")
        XCTAssertEqual(VietnameseTextPolisher.polish("la gi"), "là gì")

        // Preserve legitimate non-modified collocations
        XCTAssertEqual(VietnameseTextPolisher.polish("nội dung này"), "nội dung này")
        XCTAssertEqual(VietnameseTextPolisher.polish("người dùng mới"), "người dùng mới")
        XCTAssertEqual(VietnameseTextPolisher.polish("thực sự là rất tốt"), "thực sự là rất tốt")
        XCTAssertEqual(VietnameseTextPolisher.polish("đúng ra phải làm"), "đúng ra phải làm")
        XCTAssertEqual(VietnameseTextPolisher.polish("đúng nghĩa là chuẩn"), "đúng nghĩa là chuẩn")
    }

    // MARK: - 5. Bilingual Safety Verification
    func testBilingualSafety_EnglishSentencesNotAltered() {
        let vietnameseDiacritics = CharacterSet(charactersIn: "áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ")

        // 1. "a sunny day" must remain English
        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("a sunny day"))
        let polishedSunnyDay = VietnameseTextPolisher.polish("a sunny day")
        XCTAssertNil(
            polishedSunnyDay.rangeOfCharacter(from: vietnameseDiacritics),
            "English sentence 'a sunny day' must not contain Vietnamese diacritics: got '\(polishedSunnyDay)'"
        )
        XCTAssertEqual(polishedSunnyDay.lowercased(), "a sunny day")

        // 2. "la la land" must remain English
        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("la la land"))
        let polishedLaLaLand = VietnameseTextPolisher.polish("la la land")
        XCTAssertNil(
            polishedLaLaLand.rangeOfCharacter(from: vietnameseDiacritics),
            "English title 'la la land' must not contain Vietnamese diacritics: got '\(polishedLaLaLand)'"
        )
        XCTAssertEqual(polishedLaLaLand.lowercased(), "la la land")

        // 3. Other common English sentences with potential homographs
        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("can you help me"))
        XCTAssertEqual(VietnameseTextPolisher.polish("can you help me").lowercased(), "can you help me")

        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("go to school"))
        XCTAssertEqual(VietnameseTextPolisher.polish("go to school").lowercased(), "go to school")

        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("have a good day"))
        XCTAssertEqual(VietnameseTextPolisher.polish("have a good day").lowercased(), "have a good day")
    }

    // MARK: - 6. OnDeviceAIEngine Refinement Validation
    func testOnDeviceAIEngine_ValidRefinement() {
        let isValid = OnDeviceAIEngine.isValidRefinement(
            base: "cah su dung day la gi",
            candidate: "cách sử dụng đây là gì"
        )
        XCTAssertTrue(isValid, "Refinement from 'cah su dung day la gi' to 'cách sử dụng đây là gì' must be valid")

        XCTAssertTrue(OnDeviceAIEngine.areGrammaticallyEquivalentTokens("cah", "cach"))
        XCTAssertTrue(OnDeviceAIEngine.areGrammaticallyEquivalentTokens("day", "đây"))
        XCTAssertTrue(OnDeviceAIEngine.areGrammaticallyEquivalentTokens("la", "là"))
        XCTAssertTrue(OnDeviceAIEngine.areGrammaticallyEquivalentTokens("gi", "gì"))
        XCTAssertTrue(OnDeviceAIEngine.areGrammaticallyEquivalentTokens("ko", "khong"))
        XCTAssertTrue(OnDeviceAIEngine.areGrammaticallyEquivalentTokens("dc", "duoc"))
    }

    // MARK: - 7. Relaxed Edit Distance Matching
    func testRelaxedAsciiEditDistance() {
        // 1-deletion typo: "cah" (len 3) vs "cach" (len 4)
        XCTAssertEqual(SuggestionEngine.asciiEditDistance("cah", "cach"), 1)
        XCTAssertLessThanOrEqual(abs("cah".count - "cach".count), 1)

        // 1-substitution typo: "caxh" (len 4) vs "cach" (len 4)
        XCTAssertEqual(SuggestionEngine.asciiEditDistance("caxh", "cach"), 1)
    }

    // MARK: - 8. English Repeated-Letter Typos & "i cannn do it " Suggestion Verification
    func testEnglishRepeatedLettersAndICannnDoItSuggestions() {
        let vietnameseDiacritics = CharacterSet(charactersIn: "áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ")

        // 1. Direct polisher verification for "i cannn do it" and "i cannn do it "
        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("i cannn do it"))
        XCTAssertTrue(VietnameseTextPolisher.isPrimarilyEnglish("i cannn do it "))
        XCTAssertEqual(VietnameseTextPolisher.polish("i cannn do it"), "I can do it")
        XCTAssertEqual(VietnameseTextPolisher.polish("i cannn do it "), "I can do it")
        XCTAssertEqual(VietnameseTextPolisher.polish("i cantt dooo ittt"), "I can't do it")
        XCTAssertEqual(VietnameseTextPolisher.polish("she dontt know how to fixxx it"), "She doesn't know how to fix it")

        // 2. SuggestionEngine when user is at the end of "i cannn do it " (after trailing space)
        let afterSpaceSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: ["i", "cannn", "do", "it"],
            fullSentenceText: "i cannn do it ",
            promoteAIPolishOnHighSeverity: true
        )
        XCTAssertFalse(afterSpaceSuggestions.isEmpty, "Suggestions for 'i cannn do it ' must not be empty")
        XCTAssertEqual(afterSpaceSuggestions.first?.kind, .aiPolish)
        XCTAssertEqual(afterSpaceSuggestions.first?.text, "I can do it")
        XCTAssertTrue(
            afterSpaceSuggestions.contains(where: { $0.text == "I can't do it" }),
            "Should also offer contraction variant 'I can't do it'"
        )
        for item in afterSpaceSuggestions {
            XCTAssertNil(
                item.text.rangeOfCharacter(from: vietnameseDiacritics),
                "English suggestion '\(item.text)' must never contain Vietnamese diacritics"
            )
        }

        // 3. SuggestionEngine while typing "cannn" in "i cannn"
        let typingCannnSuggestions = SuggestionEngine.suggest(
            currentWord: "cannn",
            rawWord: "cannn",
            sentenceWords: ["i"],
            fullSentenceText: "i cannn",
            promoteAIPolishOnHighSeverity: false
        )
        XCTAssertFalse(typingCannnSuggestions.isEmpty)
        XCTAssertEqual(typingCannnSuggestions.first?.text, "can")
        XCTAssertTrue(typingCannnSuggestions.contains(where: { $0.text == "I can" && $0.kind == .aiPolish }))

        // 4. SuggestionEngine right after pressing Space on "i cannn "
        let afterCannnSpaceSuggestions = SuggestionEngine.suggest(
            currentWord: "",
            rawWord: "",
            sentenceWords: ["i", "cannn"],
            fullSentenceText: "i cannn ",
            promoteAIPolishOnHighSeverity: false
        )
        XCTAssertTrue(
            afterCannnSpaceSuggestions.contains(where: { $0.text == "can" && $0.replaceLastCompletedWord }),
            "After pressing Space on 'i cannn ', should offer 1-click replacement 'can' for 'cannn'"
        )
        XCTAssertTrue(
            afterCannnSpaceSuggestions.contains(where: { $0.text == "I can" && $0.kind == .aiPolish }),
            "After pressing Space on 'i cannn ', should offer full-sentence polish 'I can'"
        )

        // 5. OnDeviceAIEngine refinement guard must reject Vietnamese diacritics on English sentences
        XCTAssertTrue(OnDeviceAIEngine.isValidRefinement(base: "I cannn do it", candidate: "I can do it"))
        XCTAssertFalse(OnDeviceAIEngine.isValidRefinement(base: "I can do it", candidate: "I cần do ít"))
    }
}
