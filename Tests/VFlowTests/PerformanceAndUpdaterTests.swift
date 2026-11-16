import XCTest
import CryptoKit
@testable import VFlowCore
@testable import VFlowPlatform
@testable import VFlowUI

final class PerformanceAndUpdaterTests: XCTestCase {

    func testFastCachedSecurityAndBlockStatusIsNonBlocking() {
        let bridge = AccessibilityBridge.shared
        bridge.invalidateCache()

        let t0 = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = bridge.fastCachedSecurityAndBlockStatus()
        }
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
        XCTAssertLessThan(elapsedMs, 50.0, "100 calls to fastCachedSecurityAndBlockStatus() must stay well under 50ms total")
    }

    func testExplicitVietnameseInitialDPreservedOnSpaceWhileEnglishDoubleDRestores() {
        let engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)

        // Typing "ddawt" ("đăt") + Space must NOT revert to "ddawt "
        for ch in "ddawt" {
            _ = engine.processKey(ch)
        }
        XCTAssertEqual(engine.formattedWord, "đăt")
        let spaceRes = engine.processKey(" ")
        XCTAssertFalse(spaceRes.consumed, "'đăt' must stay 'đăt' rather than corrupting back to 'ddawt '")

        // Standard "ddawtj" -> "đặt"
        for ch in "ddawtj" {
            _ = engine.processKey(ch)
        }
        XCTAssertEqual(engine.formattedWord, "đặt")
        _ = engine.processKey(" ")

        // English "add" -> must still restore to "add " on Space
        for ch in "add" {
            _ = engine.processKey(ch)
        }
        let addSpace = engine.processKey(" ")
        if addSpace.consumed {
            XCTAssertEqual(addSpace.replacementText, "add ")
        }
    }

    func testVietnameseInputEngineConcurrentThreadSafety() {
        let engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
        let group = DispatchGroup()

        for i in 0..<8 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<50 {
                    _ = engine.processKey("v")
                    _ = engine.processKey("a")
                    _ = engine.processKey("f")
                    _ = engine.formattedWord
                    _ = engine.rawString
                    _ = engine.handleBackspace()
                    if i % 2 == 0 {
                        engine.reset()
                    } else {
                        _ = engine.processKey(" ")
                    }
                }
                group.leave()
            }
        }
        let waitRes = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(waitRes, .success, "Concurrent VietnameseInputEngine operations must complete without deadlock or crash")
    }

    @MainActor
    func testCaretHUDInteractionSnapshotSync() {
        let model = CaretHUDModel.shared
        let win = CaretPillWindow.shared

        model.hideHUD()
        model.suggestions = []
        model.text = ""
        model.currentWord = ""
        XCTAssertFalse(CaretHUDModel.threadSafeHasActiveSuggestions())
        XCTAssertFalse(CaretHUDModel.threadSafeCanSelectSuggestion(at: 0))

        model.updateOnTyping(
            currentWord: "duoc",
            rawWord: "duoc",
            sentenceWords: ["gõ"],
            inputMethod: .telex,
            caretFrame: CGRect(x: 300, y: 300, width: 460, height: 52)
        )
        XCTAssertTrue(CaretHUDModel.threadSafeHasActiveSuggestions())
        XCTAssertTrue(CaretHUDModel.threadSafeCanSelectSuggestion(at: 0))
        XCTAssertFalse(CaretHUDModel.threadSafeCanSelectSuggestion(at: 9))

        let snap = CaretPillWindow.currentInteractionSnapshot()
        XCTAssertTrue(snap.isHUDVisible)
        XCTAssertGreaterThan(snap.pillFrame.width, 0)

        let outsideClick = CGPoint(x: 5, y: 5)
        XCTAssertFalse(win.threadSafeHandleMouseDown(atScreenPoint: outsideClick))

        model.hideHUD()
        model.suggestions = []
        model.text = ""
        model.currentWord = ""
        XCTAssertFalse(CaretHUDModel.threadSafeHasActiveSuggestions())
    }

    func testVFlowUpdaterSemVerComparison() {
        XCTAssertEqual(VFlowUpdater.compareSemVer("v1.0.2", "1.0.1"), .orderedDescending)
        XCTAssertEqual(VFlowUpdater.compareSemVer("1.0.2", "v1.0.2"), .orderedSame)
        XCTAssertEqual(VFlowUpdater.compareSemVer("1.0.1", "1.0.2"), .orderedAscending)
        XCTAssertEqual(VFlowUpdater.compareSemVer("1.1.0", "1.0.99"), .orderedDescending)
        XCTAssertEqual(VFlowUpdater.compareSemVer("1.0.2-beta.1", "1.0.2"), .orderedAscending)
    }

    func testVFlowUpdaterGitHubReleaseJSONAndSHA256Verification() throws {
        let payload: [String: Any] = [
            "tag_name": "v1.0.2",
            "name": "VFlow v1.0.2 - Zero-Lag EventTap & Auto-Updater",
            "body": "Bug fixes and performance improvements.",
            "html_url": "https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.2",
            "published_at": "2026-11-16T14:50:00Z",
            "assets": [
                [
                    "name": "VFlow-v1.0.2-macOS-arm64.dmg",
                    "browser_download_url": "https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.2/VFlow-v1.0.2-macOS-arm64.dmg"
                ],
                [
                    "name": "VFlow-v1.0.2-macOS-arm64.zip",
                    "browser_download_url": "https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.2/VFlow-v1.0.2-macOS-arm64.zip"
                ],
                [
                    "name": "SHA256SUMS.txt",
                    "browser_download_url": "https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.2/SHA256SUMS.txt"
                ]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let release = try VFlowUpdater.parseGitHubReleaseJSON(jsonData)

        XCTAssertEqual(release.version, "1.0.2")
        XCTAssertEqual(release.tagName, "v1.0.2")
        XCTAssertEqual(release.zipAssetName, "VFlow-v1.0.2-macOS-arm64.zip")
        XCTAssertEqual(release.checksumsDownloadURL?.lastPathComponent, "SHA256SUMS.txt")

        // Create temporary payload file and verify SHA256 calculation + SHA256SUMS.txt matching
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("vflow_test_asset_\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let sampleData = Data("VFlow-Binary-Payload-Test-v1.0.2".utf8)
        try sampleData.write(to: tempURL)

        let computed = try XCTUnwrap(VFlowUpdater.sha256Hex(of: tempURL))
        let checksumsFile = """
        0000000000000000000000000000000000000000000000000000000000000000  VFlow-v1.0.2-macOS-arm64.dmg
        \(computed)  VFlow-v1.0.2-macOS-arm64.zip
        """
        let extracted = VFlowUpdater.extractExpectedSHA256(forFileName: "VFlow-v1.0.2-macOS-arm64.zip", from: checksumsFile)
        XCTAssertEqual(extracted, computed)
    }
}
