import XCTest
import AppKit
@testable import VFlowPlatform

final class SmartPasteboardTests: XCTestCase {

    func testPasteboardBackupAndRestore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let originalText = "VFlow-Test-Clipboard-Original-\(UUID().uuidString)"
        pasteboard.setString(originalText, forType: .string)

        // Capture backup
        let backup = ClipboardFallback.shared.backupPasteboard()
        XCTAssertFalse(backup.isEmpty)

        // Overwrite pasteboard
        pasteboard.clearContents()
        pasteboard.setString("Temporary-Injected-Text", forType: .string)
        XCTAssertEqual(pasteboard.string(forType: .string), "Temporary-Injected-Text")

        // Restore backup
        ClipboardFallback.shared.restorePasteboard(backup)
        XCTAssertEqual(pasteboard.string(forType: .string), originalText)
    }

    func testAutocompleteDetector() {
        XCTAssertTrue(AutocompleteDetector.isAutocompleteField(bundleId: "com.apple.Spotlight"))
        XCTAssertTrue(AutocompleteDetector.isAutocompleteField(bundleId: "com.raycast.macos"))
        XCTAssertTrue(AutocompleteDetector.isAutocompleteField(bundleId: "com.apple.Safari", subrole: "AXSearchField"))
        XCTAssertFalse(AutocompleteDetector.isAutocompleteField(bundleId: "com.apple.Notes"))
    }
}
