import XCTest
@testable import VFlowCore
@testable import VFlowPlatform

final class MutationVerificationTests: XCTestCase {

    // MARK: - Mutant 1 Verification (Tone Removal with 'z' and '0')

    func testMutant1_SabotagedToneRemovalFailsSpecification() {
        let telexEngine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern)
        for ch in "toans" { _ = telexEngine.processKey(ch) }
        XCTAssertEqual(telexEngine.formattedWord, "toán")

        let zResult = telexEngine.processKey("z")
        XCTAssertEqual(telexEngine.formattedWord, "toan", "Main build must successfully strip tone on 'z'")
        XCTAssertTrue(zResult.consumed)

        let vniEngine = VietnameseInputEngine(inputMethod: .vni, tonePlacement: .modern)
        for ch in "toan1" { _ = vniEngine.processKey(ch) }
        XCTAssertEqual(vniEngine.formattedWord, "toán")
        let zeroResult = vniEngine.processKey("0")
        XCTAssertEqual(vniEngine.formattedWord, "toan", "Main build must successfully strip tone on '0' in VNI")
        XCTAssertTrue(zeroResult.consumed)
    }

    // MARK: - Mutant 2 Verification (Auto-English Restore)

    func testMutant2_BypassedEnglishRestoreFailsSpecification() {
        let mainEngine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
        for ch in "window" { _ = mainEngine.processKey(ch) }
        XCTAssertEqual(mainEngine.formattedWord, "window", "Main build must keep 'window' intact in real-time")
        _ = mainEngine.processKey(" ")

        for ch in "test" { _ = mainEngine.processKey(ch) }
        let mainSpaceRes = mainEngine.processKey(" ")
        XCTAssertEqual(mainSpaceRes.replacementText, "test ", "Main build must restore 'test ' on Space")

        let noRestoreEngine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: false)
        for ch in "test" { _ = noRestoreEngine.processKey(ch) }
        let noRestoreSpaceRes = noRestoreEngine.processKey(" ")
        XCTAssertNotEqual(noRestoreSpaceRes.replacementText, "test ", "When autoEnglishRestore is false, 'test ' must not be restored")
    }

    // MARK: - Mutant 3 Verification (Autocomplete Guard & CaretLocator Flip & Polisher)

    func testMutant3_SabotagedAutocompleteDetectorFailsSpecification() {
        let isSafari = AutocompleteDetector.isAutocompleteField(bundleId: "com.apple.Safari", subrole: "AXSearchField")
        let isSpotlight = AutocompleteDetector.isAutocompleteField(bundleId: "com.apple.Spotlight")
        let isChrome = AutocompleteDetector.isAutocompleteField(bundleId: "com.google.Chrome", subrole: "AXURLField")
        XCTAssertTrue(isSafari, "Must detect Safari URL/Search field")
        XCTAssertTrue(isSpotlight, "Must detect Spotlight launcher")
        XCTAssertTrue(isChrome, "Must detect Chrome address field")

        let isXcode = AutocompleteDetector.isAutocompleteField(bundleId: "com.apple.dt.Xcode", subrole: "AXTextArea")
        let isVSCode = AutocompleteDetector.isAutocompleteField(bundleId: "com.microsoft.VSCode", subrole: "AXTextArea")
        XCTAssertFalse(isXcode, "Must not flag Xcode source editor as autocomplete field")
        XCTAssertFalse(isVSCode, "Must not flag VSCode source editor as autocomplete field")
    }

    func testMutant3_SabotagedCaretLocatorFlipFailsSpecification() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let caretNearTop = CGRect(x: 500, y: 870, width: 2, height: 16)
        let pillSize = CGSize(width: 385, height: 38)

        let frame = CaretLocator.calculatePillFrame(caretRect: caretNearTop, pillSize: pillSize, screenFrame: screen)
        XCTAssertEqual(frame.origin.y, 822.0, "CaretLocator must flip below caret when clipping top")
        XCTAssertLessThanOrEqual(frame.maxY, screen.maxY, "HUD must not clip top of screen")
    }

    func testMutant3_SabotagedTextPolisherFailsSpecification() {
        let input = "à ừm ko biết ntn có đc ko"

        let mainResult = VietnameseTextPolisher.polish(input, tone: .natural)
        XCTAssertEqual(mainResult, "không biết như thế nào có được không")
        XCTAssertFalse(mainResult.contains("à ừm"), "Filler words must be removed")
        XCTAssertFalse(mainResult.contains("ko"), "Teencode must be expanded")
        XCTAssertNotEqual(mainResult, input, "TextPolisher must not return raw input unchanged")
    }
}
