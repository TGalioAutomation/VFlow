import XCTest
import CoreGraphics
@testable import VFlowPlatform

final class CaretLocatorTests: XCTestCase {

    func testNormalAnchorPlacement10pxAboveCaret() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let caret = CGRect(x: 500, y: 400, width: 2, height: 16)
        let pillSize = CGSize(width: 385, height: 38)

        let frame = CaretLocator.calculatePillFrame(caretRect: caret, pillSize: pillSize, screenFrame: screen)

        // Height & Width
        XCTAssertEqual(frame.width, 385)
        XCTAssertEqual(frame.height, 38)

        // Normal anchor: caret.maxY (416) + 10 = 426
        XCTAssertEqual(frame.origin.y, 426)

        // Centered horizontally: caret.midX (501) - 385/2 (192.5) = 308.5
        XCTAssertEqual(frame.origin.x, 308.5)
    }

    func testAnchorScreenFlipWhenNearTop() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        // Caret is near the top of the screen (y = 870, height = 16 -> maxY = 886)
        // Normal originY would be 886 + 10 = 896, but 896 + 38 = 934 > screen.maxY (900)
        let caret = CGRect(x: 500, y: 870, width: 2, height: 16)
        let pillSize = CGSize(width: 385, height: 38)

        let frame = CaretLocator.calculatePillFrame(caretRect: caret, pillSize: pillSize, screenFrame: screen)

        // Must flip to 10px below caret: caret.minY (870) - 38 - 10 = 822
        XCTAssertEqual(frame.origin.y, 822)
    }

    func testHorizontalClampingNearLeftEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        // Caret is at left edge
        let caret = CGRect(x: 10, y: 400, width: 2, height: 16)
        let pillSize = CGSize(width: 385, height: 38)

        let frame = CaretLocator.calculatePillFrame(caretRect: caret, pillSize: pillSize, screenFrame: screen)

        // Clamped to screen.minX + 8 = 8
        XCTAssertEqual(frame.origin.x, 8.0)
    }

    func testHorizontalClampingNearRightEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        // Caret is at right edge
        let caret = CGRect(x: 1430, y: 400, width: 2, height: 16)
        let pillSize = CGSize(width: 385, height: 38)

        let frame = CaretLocator.calculatePillFrame(caretRect: caret, pillSize: pillSize, screenFrame: screen)

        // Clamped to screen.maxX (1440) - 385 - 8 = 1047
        XCTAssertEqual(frame.origin.x, 1047.0)
    }
}
