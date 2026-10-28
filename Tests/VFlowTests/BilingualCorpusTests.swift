import XCTest
@testable import VFlowCore

/// Comprehensive bilingual corpus test suite fulfilling Milestone 4 Requirement R4-CORPUS:
/// 1. At least 100 distinct Vietnamese words (complex diphthongs/triphthongs, -nh/-ch/-ng finals,
///    free-order Telex keys, and unsigned shorthand words) achieving 100% exact match.
/// 2. At least 100 distinct English and technical words (developer keywords, homographs, everyday words)
///    achieving 100% exact match without diacritic corruption.
/// 3. Mixed bilingual sentence typing verifying zero false reversion and seamless language transitions.
final class BilingualCorpusTests: XCTestCase {
    var engine: VietnameseInputEngine!

    override func setUp() {
        super.setUp()
        engine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)
    }

    // Helper simulating keystroke processing through the engine with Space completion
    private func typeWordWithSpace(_ keystrokes: String) -> String {
        engine.reset()
        var output = ""
        for ch in keystrokes {
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
        let spaceRes = engine.processKey(" ")
        if spaceRes.consumed {
            if spaceRes.backspaceCount > 0 {
                output = String(output.dropLast(min(spaceRes.backspaceCount, output.count)))
            }
            output += spaceRes.replacementText
        } else {
            output.append(" ")
        }
        return output
    }

    // Helper simulating multi-word sentence typing
    private func typeSentence(_ keystrokesSentence: String) -> String {
        engine.reset()
        var output = ""
        for ch in keystrokesSentence {
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

    // MARK: - Task 2.1: 100+ Vietnamese Words Corpus Test

    func testVietnameseCorpus100Words() {
        // A curated catalog of 115 distinct Vietnamese words covering:
        // - Complex diphthongs and triphthongs (nghiêng, thương, thuở, người, rượu, chiều, chuối, đuôi, buổi, ngoài, khoái, ...)
        // - Finals in -nh, -ch, -ng (mạnh, thích, sách, trắng, tiếng, ...)
        // - Free-order Telex keystrokes (vieest, toasn, toarn, tieest, quyeest, ...)
        // - Unsigned shorthand tokens (ko, dc, trc, ntn, mn, dduoc, ...)
        let corpus: [(raw: String, expected: String)] = [
            // 1. Complex diphthongs & triphthongs
            ("nghieeng", "nghiêng "),
            ("thuowng", "thương "),
            ("chuoois", "chuối "),
            ("thuowr", "thuở "),
            ("nguowif", "người "),
            ("ruowuj", "rượu "),
            ("dduooi", "đuôi "),
            ("buoorir", "buổi "),
            ("chieeuf", "chiều "),
            ("ruoongj", "ruộng "),
            ("khoasc", "khoác "),
            ("loangx", "loãng "),
            ("hoangf", "hoàng "),
            ("khoangr", "khoảng "),
            ("tieengs", "tiếng "),
            ("dduowngf", "đường "),
            ("huowngs", "hướng "),
            ("luowngx", "lưỡng "),
            ("nuowsc", "nước "),
            ("buowsc", "bước "),
            ("truowngf", "trường "),
            ("phuowng", "phương "),
            ("ngoaif", "ngoài "),
            ("khoais", "khoái "),
            ("nguoosnf", "nguồn "),
            ("cuoocj", "cuộc "),
            ("buoocj", "buộc "),
            ("luoon", "luôn "),
            ("chuoong", "chuông "),
            ("muoon", "muôn "),
            ("xoays", "xoáy "),
            ("khuoon", "khuôn "),
            ("huowng", "hương "),
            ("vuownf", "vườn "),
            ("muowif", "mười "),
            ("cuowif", "cười "),
            ("tuowi", "tươi "),
            ("duowis", "dưới "),
            ("truowsc", "trước "),
            ("nguowsc", "ngước "),
            ("tuyeets", "tuyết "),
            ("thuyeenf", "thuyền "),
            ("chuyeenj", "chuyện "),

            // 2. Finals in -nh, -ch, -ng
            ("manhj", "mạnh "),
            ("thichs", "thích "),
            ("langf", "làng "),
            ("sachs", "sách "),
            ("bongs", "bóng "),
            ("trawngs", "trắng "),
            ("xinh", "xinh "),
            ("eexchs", "ếch "),
            ("thanhf", "thành "),
            ("nhanh", "nhanh "),
            ("tranhs", "tránh "),
            ("banhs", "bánh "),
            ("canh", "canh "),
            ("xanh", "xanh "),
            ("lanhj", "lạnh "),
            ("hanhj", "hạnh "),
            ("tinhf", "tình "),
            ("minhf", "mình "),
            ("hinhf", "hình "),
            ("chinhs", "chính "),
            ("ddinhr", "đỉnh "),
            ("linhs", "lính "),
            ("kinhs", "kính "),
            ("vinh", "vinh "),
            ("sinh", "sinh "),
            ("beenhj", "bệnh "),
            ("leenhj", "lệnh "),
            ("keenh", "kênh "),
            ("meenhj", "mệnh "),
            ("gachj", "gạch "),
            ("sachj", "sạch "),
            ("bachj", "bạch "),
            ("machj", "mạch "),
            ("dichj", "dịch "),
            ("lichj", "lịch "),
            ("tichj", "tịch "),
            ("kichj", "kịch "),
            ("ddichs", "đích "),
            ("tachs", "tách "),
            ("khachs", "khách "),
            ("rachs", "rách "),
            ("quang", "quang "),
            ("thangs", "tháng "),
            ("vangf", "vàng "),
            ("nawngs", "nắng "),
            ("sangs", "sáng "),
            ("bangr", "bảng "),
            ("mangj", "mạng "),
            ("cangr", "cảng "),
            ("hangx", "hãng "),
            ("roongj", "rộng "),
            ("ddongs", "đóng "),
            ("soongs", "sống "),
            ("troongs", "trống "),
            ("choongs", "chống "),
            ("coongj", "cộng "),
            ("moongj", "mộng "),
            ("longf", "lòng "),
            ("vongf", "vòng "),
            ("dongf", "dòng "),

            // 3. Free-order Telex keystrokes
            ("vieest", "viết "),
            ("toasn", "toán "),
            ("toarn", "toản "),
            ("tieest", "tiết "),
            ("quyeest", "quyết "),
            ("suoost", "suốt "),
            ("thieest", "thiết "),
            ("suost", "suót "),
            ("thiest", "thiét "),
            ("ddansh", "đánh "),

            // 4. Unsigned and Shorthand words
            ("ko", "không "),
            ("dc", "được "),
            ("đc", "được "),
            ("trc", "trước "),
            ("ntn", "như thế nào "),
            ("mn", "mọi người "),
            ("dduoc", "được "),
            ("duoc", "được "),
            ("khong", "không "),
            ("nhung", "nhưng "),
            ("chua", "chưa "),
            ("nguoi", "người "),
            ("truoc", "trước ")
        ]

        // Assert strictly at least 100 distinct items
        let uniqueCount = Set(corpus.map { $0.expected.trimmingCharacters(in: .whitespaces) }).count
        XCTAssertGreaterThanOrEqual(uniqueCount, 100, "Vietnamese corpus must contain at least 100 distinct words")

        for (index, item) in corpus.enumerated() {
            let actual = typeWordWithSpace(item.raw)
            XCTAssertEqual(
                actual,
                item.expected,
                "[\(index + 1)/\(corpus.count)] Vietnamese word keystroke '\(item.raw)' produced '\(actual)', expected '\(item.expected)'"
            )
        }
    }

    // MARK: - Task 2.2: 100+ English & Technical Words Corpus Test

    func testEnglishAndTechnicalCorpus100Words() {
        // A curated catalog of 110 distinct English and developer keywords
        // verifying zero false diacritic corruption (e.g. if -> ì, of -> ò, var -> vả, down -> dơn)
        let corpus: [String] = [
            // Swift & Developer Keywords
            "const", "var", "func", "if", "of", "return", "import", "export",
            "let", "class", "struct", "enum", "public", "private", "static",
            "guard", "switch", "case", "break", "continue", "default", "where",
            "catch", "throw", "try", "async", "await", "actor", "self", "super",
            "nil", "true", "false", "typealias", "protocol", "extension", "init",
            "deinit", "mutating", "nonmutating", "override", "final", "open", "weak",
            "unowned", "package", "internal", "while", "for", "in", "repeat",

            // Everyday Words with Potential Diacritic Conflicts
            "down", "town", "door", "floor", "major", "poor", "brown", "clown",
            "dust", "window", "status", "safari", "about", "action", "auto",
            "base", "button", "click", "code", "command", "control", "copy",
            "data", "debug", "delete", "device", "display", "edit", "error",
            "event", "file", "find", "font", "format", "frame", "global",
            "group", "help", "hook", "icon", "image", "index", "input",
            "item", "key", "label", "layer", "layout", "line", "link",
            "list", "load", "local", "lock", "main", "menu", "mode",
            "model", "mouse", "move", "name", "network", "node", "note",
            "null", "object", "output", "page", "panel", "path", "point",
            "post", "press", "print", "queue", "range", "read", "record",
            "reset", "result", "root", "row", "run", "save", "screen",
            "scroll", "search", "select", "send", "server", "set", "share",
            "shift", "show", "size", "space", "state", "step", "stop",
            "string", "style", "system", "table", "tag", "target", "task",
            "test", "text", "time", "title", "tool", "type",
            "undo", "unit", "user", "value", "view", "voice", "wave",
            "width", "height", "word", "write"
        ]

        let uniqueCount = Set(corpus).count
        XCTAssertGreaterThanOrEqual(uniqueCount, 100, "English corpus must contain at least 100 distinct words")

        for (index, word) in corpus.enumerated() {
            let actual = typeWordWithSpace(word)
            let expected = word + " "
            XCTAssertEqual(
                actual,
                expected,
                "[\(index + 1)/\(corpus.count)] English word '\(word)' corrupted to '\(actual)', expected '\(expected)'"
            )
        }
    }

    // MARK: - Task 2.3: Mixed Bilingual Sentence Verification

    func testMixedBilingualSentences() {
        let testSentences: [(raw: String, expected: String)] = [
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
                "Uwngs dungj VFlow hoox trowj gox tieengs Vieetj tuwj nhieen nhaast ",
                "Ứng dụng VFlow hỗ trợ gõ tiếng Việt tự nhiên nhất "
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
                "Gox trc mootj tuwf rooif nhaasn Space ddeer xem keest quar ",
                "Gõ trước một từ rồi nhấn Space để xem kết quả "
            ),
            (
                "Nguowif dungf ddanhs gias giao dieejn ddepj vaf hieejn ddaij ",
                "Người dùng đánh giá giao diện đẹp và hiện đại "
            )
        ]

        for (index, item) in testSentences.enumerated() {
            let actual = typeSentence(item.raw)
            XCTAssertEqual(
                actual,
                item.expected,
                "Sentence [\(index + 1)/\(testSentences.count)] mismatch.\nActual:   '\(actual)'\nExpected: '\(item.expected)'"
            )
        }
    }
}
