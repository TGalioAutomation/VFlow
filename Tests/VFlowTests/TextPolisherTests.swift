import XCTest
@testable import VFlowCore

final class TextPolisherTests: XCTestCase {

    func testSpecificationExactBenchmarkTones() {
        let input = "à ừm ko biết ntn có đc ko"

        // Natural
        let naturalOutput = VietnameseTextPolisher.polish(input, tone: .natural)
        XCTAssertEqual(naturalOutput, "không biết như thế nào có được không")

        // Polite
        let politeOutput = VietnameseTextPolisher.polish(input, tone: .polite)
        XCTAssertEqual(politeOutput, "Xin cho tôi hỏi như thế nào có được không ạ")

        // Concise
        let conciseOutput = VietnameseTextPolisher.polish(input, tone: .concise)
        XCTAssertEqual(conciseOutput, "Như thế nào có được không")
    }

    func testFillerWordsRemoval() {
        let text1 = "à ừm dự án này rất tốt"
        XCTAssertEqual(VietnameseTextPolisher.removeFillers(text1), "dự án này rất tốt")

        let text2 = "kiểu như là chúng ta cần tối ưu thêm"
        XCTAssertEqual(VietnameseTextPolisher.removeFillers(text2), "chúng ta cần tối ưu thêm")

        let text3 = "ờ thì hôm nay họp lúc 2 giờ"
        XCTAssertEqual(VietnameseTextPolisher.removeFillers(text3), "hôm nay họp lúc 2 giờ")
    }

    func testTeencodeExpansion() {
        let input = "ko đc j mn cx vs thg kb trc bh"
        let expanded = VietnameseTextPolisher.expandTeencode(input)
        XCTAssertEqual(expanded, "không được gì mọi người cũng với thường không biết trước bây giờ")
    }

    func testPunctuationNormalization() {
        let text = "xin chào   các bạn . bạn khỏe không ?"
        let normalized = VietnameseTextPolisher.normalizePunctuation(text)
        XCTAssertEqual(normalized, "xin chào các bạn. bạn khỏe không?")
    }

    func testBilingualAndEnglishPolishing() {
        let enInput = "uh um i dont know how to fix this bug plz help"
        let enNatural = VietnameseTextPolisher.polish(enInput, tone: .natural)
        XCTAssertEqual(enNatural, "I don't know how to fix this bug please help")

        let enPolite = VietnameseTextPolisher.polish(enInput, tone: .polite)
        XCTAssertTrue(enPolite.hasSuffix("— thank you."))

        let enConcise = VietnameseTextPolisher.polish(enInput, tone: .concise)
        XCTAssertEqual(enConcise, "Need help to fix this bug please help")
    }
}
