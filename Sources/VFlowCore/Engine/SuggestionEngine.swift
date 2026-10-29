import Foundation

/// Kind of real-time typing suggestion shown in the Caret Pill HUD.
public enum SuggestionKind: String, Equatable, Sendable {
    case wordCompletion
    case nextWord
    case teencodeExpansion
    case aiPolish
}

/// Configurable keyboard shortcut mode for accepting the primary suggestion (#1) on the Caret Pill HUD.
public enum SuggestionAcceptShortcut: String, CaseIterable, Identifiable, Sendable {
    case doubleTab = "doubleTab"
    case singleTab = "singleTab"
    case rightArrow = "rightArrow"
    case shiftReturn = "shiftReturn"
    case optionNumbers = "optionNumbers"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .doubleTab:
            return "Nhấn nhanh Tab + Tab (⇥⇥)"
        case .singleTab:
            return "Nhấn 1 lần Tab (⇥)"
        case .rightArrow:
            return "Phím Mũi tên phải (→)"
        case .shiftReturn:
            return "Shift + Enter (⇧↩)"
        case .optionNumbers:
            return "Chỉ dùng ⌥1 / ⌥2 / ⌥3"
        }
    }

    public var shortBadge: String {
        switch self {
        case .doubleTab:
            return "⇥⇥"
        case .singleTab:
            return "⇥"
        case .rightArrow:
            return "→"
        case .shiftReturn:
            return "⇧↩"
        case .optionNumbers:
            return "⌥1"
        }
    }

    public var subtitle: String {
        switch self {
        case .doubleTab:
            return "Nhấn đúp Tab nhanh (≤ 400ms) để dùng gợi ý — Tránh kẹt phím Tab đơn khi chuyển ô hoặc thụt lề"
        case .singleTab:
            return "Nhấn 1 lần phím Tab để chèn ngay gợi ý đầu tiên (#1)"
        case .rightArrow:
            return "Nhấn phím Mũi tên phải (→) để chèn ngay gợi ý đầu tiên (#1)"
        case .shiftReturn:
            return "Nhấn Shift + Enter để chèn gợi ý mà không gửi tin nhắn"
        case .optionNumbers:
            return "Tắt phím nhanh đơn, chỉ dùng ⌥1 / ⌥2 / ⌥3 hoặc Click chuột trực tiếp"
        }
    }
}

/// A single actionable suggestion chip displayed in the Caret Pill HUD.
public struct SuggestionItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let kind: SuggestionKind
    /// If true, selecting this suggestion replaces the currently typed word; if false, appends after space.
    public let replaceCurrentWord: Bool
    /// If true (when currentWord is empty right after Space), replaces the last completed word + trailing space.
    public let replaceLastCompletedWord: Bool
    /// Optional target word length to replace when `replaceLastCompletedWord` is true.
    public let targetWordToReplace: String
    /// Urgency/severity level of the suggestion (.normal Cyan, .moderate Amber, .high Rose).
    public let severity: SuggestionSeverity

    public init(
        text: String,
        kind: SuggestionKind,
        replaceCurrentWord: Bool = true,
        replaceLastCompletedWord: Bool = false,
        targetWordToReplace: String = "",
        severity: SuggestionSeverity = .normal
    ) {
        self.id = "\(kind.rawValue):\(text)"
        self.text = text
        self.kind = kind
        self.replaceCurrentWord = replaceCurrentWord
        self.replaceLastCompletedWord = replaceLastCompletedWord
        self.targetWordToReplace = targetWordToReplace
        self.severity = severity
    }
}

/// Real-time Vietnamese + English (Bilingual) word completion, typo recovery, next-word N-gram collocation, and AI polish suggestion engine.
public struct SuggestionEngine: Sendable {
    /// Instant single-word typo, unsigned Vietnamese, & shorthand fixes.
    public static let instantWordFixes: [String: String] = [
        "ddwuocj": "được",
        "dduwocj": "được",
        "duoc": "được",
        "dduoc": "được",
        "khoog": "không",
        "khong": "không",
        "heets": "hết",
        "het": "hết",
        "hien": "hiển thị",
        "chua": "chưa",
        "dat": "đạt",
        "loi": "lỗi",
        "phan": "phần",
        "phân": "phần",
        "bi": "bị",
        "cam": "cảm ơn",
        "tieng": "tiếng Việt",
        "viet": "Việt",
        "tot": "tốt",
        "co": "có",
        "thuc": "thực",
        "hoat": "hoạt",
        "dong": "động",
        "dang": "đang",
        "viec": "việc",
        "toi": "tôi",
        "tooi": "tôi",
        "thu": "thử",
        "dau": "dấu",
        "cau": "câu",
        "sư": "sự",
        "thaat": "thật",
        "that": "thật",
        "chuan": "chuẩn",
        "nghia": "nghĩa",
        "go": "gõ",
        "moi": "mới",
        "cah": "cách",
        "cach": "cách",
        "day": "đây",
        "la": "là",
        "gi": "gì",
        "su": "sử",
        "dung": "dụng",
        "nua": "nữa",
        "chang": "chẳng",
        "nhung": "nhưng",
        "luon": "luôn",
        "nhieu": "nhiều",
        "cung": "cũng",
        "muon": "muốn",
        "biet": "biết",
        "phai": "phải",
        "truoc": "trước",
        "nguoi": "người",
        "nghành": "ngành",
        "nghanh": "ngành",
        "ghặp": "gặp",
        "ghửi": "gửi",
        "ghọi": "gọi",
        "texxt": "text",
        "tetx": "text",
        "suge": "suggest",
        "sugge": "suggest",
        "sugget": "suggest",
        "sugest": "suggest",
        "sugestion": "suggestion",
        "suggesti": "suggestion",
        "suggestio": "suggestion",
        "verif": "verify",
        "veriaay": "verify",
        "verrify": "verify",
        "vaule": "value",
        "informations": "information",
        "advices": "advice",
        "equipments": "equipment",
        "knowledges": "knowledge",
        "feedbacks": "feedback"
    ]

    /// Contextual bigram typo & diacritic overrides (prevWord|currentWord -> corrected currentWord).
    public static let contextualBigramWordFixes: [String: String] = [
        "không|cau": "dấu",
        "khong|cau": "dấu",
        "ko|cau": "dấu",
        "không|dau": "dấu",
        "khong|dau": "dấu",
        "có|cau": "dấu",
        "co|cau": "dấu",
        "có|dau": "dấu",
        "co|dau": "dấu",
        "thật|sư": "sự",
        "thật|su": "sự",
        "thật|sử": "sự",
        "that|su": "sự",
        "that|sư": "sự",
        "that|sử": "sự",
        "thaat|sư": "sự",
        "thaat|su": "sự",
        "thaat|sử": "sự",
        "thực|sư": "sự",
        "thực|su": "sự",
        "thực|sử": "sự",
        "thuc|sư": "sự",
        "thuc|su": "sự",
        "thuc|sử": "sự",
        "đúng|nghia": "nghĩa",
        "dung|nghia": "nghĩa",
        "đúng|nghi": "nghĩa",
        "chuẩn|hon": "hơn",
        "chuan|hon": "hơn",
        "tốt|hon": "hơn",
        "tot|hon": "hơn",
        "tốt|lam": "lắm",
        "tot|lam": "lắm",
        "như|anh": "ảnh",
        "nhu|anh": "ảnh",
        "cấu|hinh": "hình",
        "cau|hinh": "hình",
        "cài|dat": "đặt",
        "cai|dat": "đặt",
        "ứng|dung": "dụng",
        "ung|dung": "dụng",
        "sử|dung": "dụng",
        "su|dung": "dụng",
        "cách|su": "sử",
        "cach|su": "sử",
        "cah|su": "sử",
        "dụng|day": "đây",
        "dung|day": "đây",
        "đây|la": "là",
        "day|la": "là",
        "là|gi": "gì",
        "la|gi": "gì",
        "người|dung": "dùng",
        "nguoi|dung": "dùng",
        "nội|dung": "dung",
        "hệ|thong": "thống",
        "he|thong": "thống",
        "chức|nang": "năng",
        "chuc|nang": "năng",
        "giao|dien": "diện",
        "kiểm|tra": "tra",
        "kiem|tra": "tra",
        "sửa|loi": "lỗi",
        "sua|loi": "lỗi",
        "hỗ|tro": "trợ",
        "ho|tro": "trợ",
        "phần|mem": "mềm",
        "phan|mem": "mềm",
        "bàn|phim": "phím",
        "ban|phim": "phím",
        "phím|tat": "tắt",
        "phim|tat": "tắt",
        "không|can": "cần",
        "khong|can": "cần",
        "cần|thiet": "thiết",
        "can|thiet": "thiết",
        "phải|nhu": "như",
        "phai|nhu": "như",
        "như|the": "thế",
        "nhu|the": "thế",
        "thế|nao": "nào",
        "the|nao": "nào",
        "bị|loi": "lỗi",
        "bi|loi": "lỗi",
        "nữa|y": "ý",
        "nua|y": "ý",
        "ý|ma": "mà",
        "y|ma": "mà",
        "nữa|ma": "mà",
        "nua|ma": "mà",
        "nhưng|ma": "mà",
        "nhung|ma": "mà",
        "mà|no": "nó",
        "ma|no": "nó",
        "không|du": "đủ",
        "khong|du": "đủ",
        "chưa|du": "đủ",
        "chua|du": "đủ",
        "khá|dai": "dài",
        "kha|dai": "dài",
        "nhưng|lai": "lại",
        "nhung|lai": "lại",
        "mà|lai": "lại",
        "ma|lai": "lại",
        "lại|khong": "không",
        "lai|khong": "không",
        // Vietnamese orthographic, compound & grammar bigram fixes
        "suy|ngĩ": "nghĩ",
        "suy|nghỉ": "nghĩ",
        "công|ngệ": "nghệ",
        "ngành|ngề": "nghề",
        "đề|ngị": "nghị",
        "ý|ngĩa": "nghĩa",
        "cập|nhập": "nhật",
        "cập|nhat": "nhật",
        "cập|nhât": "nhật",
        "cap|nhat": "nhật",
        "cải|tiếng": "tiến",
        "cải|tieng": "tiến",
        "cải|tien": "tiến",
        "cai|tieng": "tiến",
        "cai|tien": "tiến",
        "cải|thiên": "thiện",
        "cải|thien": "thiện",
        "ổn|địng": "định",
        "ổn|dinh": "định",
        "ổn|đinh": "định",
        "on|dinh": "định",
        "on|địng": "định",
        "mặc|địng": "định",
        "mặc|dinh": "định",
        "xác|địng": "định",
        "xác|dinh": "định",
        "quyết|địng": "định",
        "quyết|dinh": "định",
        "nhận|diên": "diện",
        "nhận|dien": "diện",
        "nhận|địng": "định",
        "nhận|dinh": "định",
        "ngữ|canh": "cảnh",
        "ngu|canh": "cảnh",
        "ngữ|phap": "pháp",
        "ngu|phap": "pháp",
        "kịch|ban": "bản",
        "kich|ban": "bản",
        "vấn|de": "đề",
        "van|de": "đề",
        "tra|fia": "fix",
        "cần|fia": "fix",
        "đang|fia": "fix",
        "thử|fia": "fix",
        "kịch|veriaay": "verify",
        "kịch|verif": "verify",
        "kịch|veri": "verify",
        "bản|veriaay": "verify",
        "bản|verif": "verify",
        "xác|xuất": "suất",
        "sản|suất": "xuất",
        "bổ|xung": "sung",
        "chia|sẽ": "sẻ",
        "vất|vã": "vả",
        "sẳn|sàng": "sẵn",
        "trãi|nghiệm": "trải",
        // English grammar bigram fixes
        "he|go": "goes",
        "she|go": "goes",
        "it|go": "goes",
        "he|work": "works",
        "she|work": "works",
        "it|work": "works",
        "he|dont": "doesn't",
        "she|dont": "doesn't",
        "it|dont": "doesn't",
        "he|don't": "doesn't",
        "she|don't": "doesn't",
        "it|don't": "doesn't",
        "he|have": "has",
        "she|have": "has",
        "it|have": "has",
        "he|are": "is",
        "she|are": "is",
        "it|are": "is",
        "i|is": "am",
        "i|are": "am",
        "you|is": "are",
        "we|is": "are",
        "they|is": "are",
        "you|was": "were",
        "we|was": "were",
        "they|was": "were",
        "did|went": "go",
        "didn't|went": "go",
        "didnt|went": "go",
        "did|worked": "work",
        "didn't|worked": "work",
        "didnt|worked": "work",
        "have|went": "gone",
        "has|went": "gone",
        "had|went": "gone",
        "have|did": "done",
        "has|did": "done",
        "have|saw": "seen",
        "has|saw": "seen",
        "have|wrote": "written",
        "has|wrote": "written",
        "could|of": "have",
        "would|of": "have",
        "should|of": "have",
        "must|of": "have",
        "a|apple": "an apple",
        "a|error": "an error",
        "a|issue": "an issue",
        "a|answer": "an answer"
    ]

    /// Computes ASCII edit distance between two short strings.
    public static func asciiEditDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(0...n)
        for i in 1...m {
            var prev = dp[0]
            dp[0] = i
            for j in 1...n {
                let temp = dp[j]
                if aChars[i - 1] == bChars[j - 1] {
                    dp[j] = prev
                } else {
                    dp[j] = min(prev, dp[j], dp[j - 1]) + 1
                }
                prev = temp
            }
        }
        return dp[n]
    }

    /// Contextual right-neighbor overrides (`currentWord|nextWord -> corrected currentWord`).
    public static let contextualRightBigramWordFixes: [String: String] = [
        "fia|lỗi": "fix",
        "fia|loi": "fix",
        "fia|bug": "fix",
        "fia|issue": "fix",
        "fia|error": "fix",
        "veriaay|lỗi": "verify",
        "verif|lỗi": "verify",
        "veri|lỗi": "verify",
        "dung|ra": "đúng",
        "dụng|ra": "đúng",
        "dung|nghĩa": "đúng",
        "dụng|nghĩa": "đúng",
        "dung|nghia": "đúng",
        "dụng|nghia": "đúng",
        "phân|suggest": "phần",
        "phan|suggest": "phần",
        "phân|gợi": "phần",
        "phan|mem": "phần",
        "phan|mềm": "phần",
        "sử|lý": "xử",
        "su|ly": "xử",
        "xử|dụng": "sử",
        "giành|thời": "dành",
        "giành|cho": "dành"
    ]

    /// Resolves contextual single-word typo or diacritic restoration using the preceding word (and optional following word).
    public static func resolveContextualWordFix(
        prevWord: String?,
        currentWord: String,
        wordAfterCursor: String = ""
    ) -> String? {
        let cleanCurrent = currentWord.trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard !cleanCurrent.isEmpty else { return nil }

        // Check if currentWord is a pronoun typo ("to", "t", "tooi") before a Vietnamese verb
        let cleanAfter = wordAfterCursor.trimmingCharacters(in: .punctuationCharacters).lowercased()
        let verbFollowers: Set<String> = [
            "đang", "dang", "đã", "da", "sẽ", "se", "muốn", "muon", "cần", "can",
            "thử", "thu", "gõ", "làm", "lam", "nghĩ", "nghi", "thấy", "thay", "biết", "biet", "vừa", "vua"
        ]
        let rawPrev = prevWord?.trimmingCharacters(in: .punctuationCharacters).lowercased()
        let nounAdjectiveAntecedents: Set<String> = [
            "chữ", "chu", "nhà", "nha", "xe", "cái", "cai", "con", "quả", "qua", "tiếng", "tieng",
            "loa", "phòng", "phong", "rất", "rat", "khá", "kha", "hơi", "hoi", "quá", "qua", "cực", "cuc"
        ]
        let isPrecededByNounOrAdverb = rawPrev.map { nounAdjectiveAntecedents.contains($0) } ?? false
        let isPrecededByEnglish = rawPrev.map { SmartEnglishDetector.commonEnglishWords.contains($0) || $0 == "ready" || $0 == "time" || $0 == "want" } ?? false

        if (cleanCurrent == "to" || cleanCurrent == "t" || cleanCurrent == "tooi") &&
            verbFollowers.contains(cleanAfter) &&
            !isPrecededByNounOrAdverb &&
            !isPrecededByEnglish {
            return "tôi"
        }

        // Right-neighbor contextual check (e.g. "fia lỗi" -> "fix", "veriaay lỗi" -> "verify", "phân suggest" -> "phần")
        if !cleanAfter.isEmpty, let rightFix = contextualRightBigramWordFixes["\(cleanCurrent)|\(cleanAfter)"] {
            return rightFix
        }

        guard let validPrev = rawPrev, !validPrev.isEmpty else {
            return nil
        }

        let isCauException = cleanCurrent == "cau" && (cleanAfter == "có" || cleanAfter == "co" || cleanAfter == "hỏi" || cleanAfter == "hoi" || cleanAfter == "nệ" || cleanAfter == "ne")

        if !isCauException, let direct = contextualBigramWordFixes["\(validPrev)|\(cleanCurrent)"] {
            return direct
        }

        let normPrev = (TeencodeDictionary.mapping[validPrev] ?? instantWordFixes[validPrev] ?? validPrev).lowercased()
        if !isCauException, let normMatch = contextualBigramWordFixes["\(normPrev)|\(cleanCurrent)"] {
            return normMatch
        }

        // Check nextWordCollocations for unsigned/wrong-tone match or 1-key typo match (when ASCII or malformed syllable)
        if !isCauException, let collocations = nextWordCollocations[normPrev] ?? nextWordCollocations[validPrev] {
            let singleWordCollocations = collocations.filter { !$0.contains(" ") }
            if singleWordCollocations.contains(where: { $0.lowercased() == cleanCurrent }) {
                return nil
            }
            let isPureASCII = cleanCurrent.unicodeScalars.allSatisfy { $0.value <= 127 }
            let isMalformedSyllable = !SyllableParser.isValidVietnameseSyllable(
                raw: cleanCurrent,
                formatted: cleanCurrent,
                isWordBoundary: true
            )
            let strippedCurrent = stripDiacritics(cleanCurrent)
            if isPureASCII || isMalformedSyllable {
                for cand in singleWordCollocations {
                    let candLower = cand.lowercased()
                    let strippedCand = stripDiacritics(candLower)
                    if strippedCand == strippedCurrent && candLower != cleanCurrent {
                        return cand
                    }
                }
                if strippedCurrent.count >= 3 {
                    for cand in singleWordCollocations {
                        let candLower = cand.lowercased()
                        let strippedCand = stripDiacritics(candLower)
                        if abs(strippedCand.count - strippedCurrent.count) <= 1 &&
                           strippedCand.first == strippedCurrent.first &&
                           asciiEditDistance(strippedCand, strippedCurrent) == 1 {
                            return cand
                        }
                    }
                }
            }
        }
        return nil
    }

    /// High-frequency Vietnamese words & compound phrases for instant prefix completion.
    public static let vietnamesePhrases: [String] = [
        "hiển thị", "hiển thị đầy đủ", "hiển thị được", "hiệu ứng", "hiện tại", "hệ thống", "hỗ trợ", "hoàn thành", "hoạt động", "hướng dẫn", "hết", "hết text",
        "không", "không hiển thị", "không được", "không thể", "không biết", "khắc phục", "khởi động", "kiểm tra", "kiểm thử", "kịch bản", "kịch bản kiểm thử", "kết quả", "kết nối",
        "được", "được hết", "đạt", "đạt yêu cầu", "đã", "đang", "đồng bộ", "đóng gói", "đường dẫn", "đưa ra",
        "chưa", "chưa đạt", "chưa được", "chưa ổn", "chức năng", "chương trình", "chỉnh sửa", "chính xác", "chuyển đổi", "chạy",
        "phần", "phần gợi ý", "phần hiển thị", "phần mềm", "phát triển", "phiên bản", "phím tắt", "phản hồi",
        "bị", "bị lỗi", "bị sai", "bình thường", "bổ sung", "bắt đầu", "bây giờ", "bàn phím", "báo cáo",
        "lỗi", "lỗi hiển thị", "làm mượt", "lập trình", "lựa chọn", "luôn",
        "gõ", "gõ tiếng Việt", "gợi ý", "gợi ý từ", "giải pháp", "giúp", "giao diện",
        "cần", "cần hỗ trợ", "cập nhật", "cài đặt", "cấu hình", "cảm ơn", "cải tiến", "cải thiện", "công nghệ",
        "tiếng Việt", "tiếng Anh", "tiếp tục", "tiến độ", "tính năng", "tự động", "tối ưu", "tốt", "tạo", "tìm kiếm",
        "xử lý", "xác nhận", "xây dựng", "xem", "xong", "xin cảm ơn", "xin chào",
        "và", "vào", "vấn đề", "vẫn", "với", "về", "vậy", "văn bản", "vui lòng",
        "ứng dụng", "ưu tiên", "ổn định",
        "người dùng", "nguyên nhân", "ngữ cảnh", "nhận diện", "nhanh chóng", "như thế nào", "nhưng", "nhiều", "nội dung",
        "mặc định", "môi trường", "mới", "mở", "màn hình",
        "sử dụng", "sửa lỗi", "sẵn sàng",
        "cách sử dụng", "cách sử dụng đây là gì", "đây là gì",
        "thực hiện", "thành công", "thêm", "thay đổi", "thông minh", "thử nghiệm", "thị",
        "trực tiếp", "triển khai", "trình duyệt", "trạng thái", "trước"
    ]

    /// 2-Word (Bigram) Contextual Collocations for natural phrase prediction.
    public static let bigramCollocations: [String: [String]] = [
        "không hiển": ["thị", "thị được", "thị hết"],
        "hiển thị": ["được", "đầy đủ", "hết text"],
        "thị được": ["hết", "đầy đủ", "nội dung"],
        "được hết": ["text", "nội dung", "văn bản"],
        "bị lỗi": ["hiển thị", "khi gõ", "text"],
        "chưa đạt": ["value", "yêu cầu", "kỳ vọng"],
        "chưa được": ["ổn", "tốt", "hoàn thiện"],
        "xin cảm": ["ơn", "ơn bạn"],
        "không xin": ["cảm ơn", "lỗi"],
        "gõ tiếng": ["Việt", "Anh"],
        "hỗ trợ": ["cả tiếng Việt", "tiếng Anh", "tốt"],
        "phần suggest": ["text", "chưa ổn", "bị lỗi"],
        "phân suggest": ["text", "bị lỗi"],
        "suggest text": ["bị lỗi", "chưa đạt", "tốt hơn"],
        "hoạt động": ["tốt", "ổn định", "bình thường"],
        "đang hoạt": ["động", "động tốt"],
        "thực sự": ["có", "tốt", "hoạt động tốt"],
        "thực tế": ["có", "đang", "hoạt động"],
        "vấn đề": ["ngữ cảnh", "hiển thị", "cần cải tiến"],
        "ngữ cảnh": ["cần cải tiến", "câu", "thông minh"],
        "cần cải": ["tiến", "thiện"],
        "không nhận": ["diện", "ổn định", "được"],
        "ổn định": ["hơn", "khi cập nhật", "rồi"],
        "cập nhật": ["ổn định", "thành công", "lại"],
        "kiểm tra": ["fix lỗi", "lại", "kịch bản"],
        "fix lỗi": ["suggestion", "hiển thị", "ngữ cảnh"],
        "kịch bản": ["verify lỗi", "kiểm thử", "test"]
    ]

    /// Single-Word (Unigram) Next-word collocations following a completed word.
    public static let nextWordCollocations: [String: [String]] = [
        "thực": ["sự", "tế", "hiện"],
        "thật": ["sự", "tốt", "ra"],
        "đang": ["hoạt động", "chạy", "xử lý", "thử"],
        "hoạt": ["động", "động tốt"],
        "động": ["tốt", "ổn định", "bình thường"],
        "có": ["đang", "hoạt động", "dấu", "được"],
        "không": ["hiển thị", "dấu", "được", "thể"],
        "đúng": ["nghĩa", "chuẩn", "ra"],
        "nghĩa": ["chuẩn", "rõ", "đúng"],
        "chuẩn": ["hơn", "xác"],
        "tốt": ["hơn", "lắm", "nhất"],
        "Việt": ["không dấu", "có dấu", "và tiếng Anh"],
        "việt": ["không dấu", "có dấu", "và tiếng Anh"],
        "hiển": ["thị", "thị được", "thị hết"],
        "thị": ["được", "hết", "đầy đủ"],
        "được": ["hết", "đầy đủ", "nhiều"],
        "hết": ["text", "nội dung", "văn bản"],
        "bị": ["lỗi", "sai", "thiếu"],
        "lỗi": ["hiển thị", "khi gõ", "text"],
        "chưa": ["đạt", "được", "ổn"],
        "đạt": ["value", "yêu cầu", "chuẩn"],
        "phần": ["suggest", "gợi ý", "hiển thị"],
        "phân": ["tích", "biệt", "loại"],
        "suggest": ["text", "tốt hơn", "nhanh"],
        "text": ["tiếng Việt", "đầy đủ", "chính xác"],
        "value": ["tốt hơn", "cao", "kỳ vọng"],
        "hỗ": ["trợ", "trợ thêm", "trợ tiếng Việt"],
        "hiệu": ["ứng", "suất", "quả"],
        "tiếng": ["Việt", "Anh", "Việt và tiếng Anh"],
        "cần": ["hỗ trợ", "xử lý", "kiểm tra", "cải tiến"],
        "xử": ["lý", "lý ngay", "lý lỗi"],
        "kiểm": ["tra", "thử", "tra lại"],
        "cài": ["đặt", "đặt thêm"],
        "cấu": ["hình", "trúc"],
        "gõ": ["tiếng Việt", "văn bản", "nhanh"],
        "vào": ["ô text", "ứng dụng", "hệ thống"],
        "ô": ["text", "nhập liệu"],
        "ứng": ["dụng"],
        "chức": ["năng"],
        "chương": ["trình"],
        "hệ": ["thống"],
        "người": ["dùng"],
        "nguyên": ["nhân"],
        "hiện": ["tại", "thị", "nay"],
        "hoàn": ["thành", "tất"],
        "phím": ["tắt"],
        "bàn": ["phím"],
        "sửa": ["lỗi", "đổi"],
        "tính": ["năng", "toán"],
        "cảm": ["ơn", "ơn bạn"],
        "ơn": ["bạn", "nhiều"],
        "xin": ["cảm ơn", "chào", "lỗi"],
        "đã": ["OK", "hoàn thành", "xong"],
        "gợi": ["ý", "ý từ", "ý thông minh"],
        "ổn": ["định", "thỏa"],
        "định": ["cập nhật", "hơn", "lại"],
        "cập": ["nhật", "nhật lại"],
        "nhật": ["ổn định", "thành công", "ngay"],
        "cải": ["tiến", "thiện", "tạo"],
        "ngữ": ["cảnh", "pháp", "nghĩa"],
        "cảnh": ["cần cải tiến", "câu", "sử dụng"],
        "vấn": ["đề"],
        "đề": ["ngữ cảnh", "hiển thị", "này"],
        "kịch": ["bản", "bản verify", "bản kiểm thử"],
        "nhận": ["diện", "định", "được"],
        "verify": ["lỗi", "lỗi suggestion", "kịch bản"],
        "fix": ["lỗi", "lỗi suggestion", "bug"]
    ]

    /// High-frequency English technical & everyday words for prefix completion.
    public static let englishCompletions: [String] = [
        "can", "can't", "cannot", "could", "couldn't", "should", "shouldn't", "would", "wouldn't", "will", "won't",
        "please", "thanks", "thank you", "today", "tomorrow", "yesterday", "because", "believe", "receive", "separate", "definitely",
        "suggest", "suggestion", "suggestions", "support", "system", "settings", "service", "server", "screen", "search", "status",
        "value", "values", "validation", "verify", "verified", "verification", "version", "view", "vietnamese",
        "text", "textarea", "testing", "terminal", "typescript", "token", "tab",
        "fix", "fixed", "focus", "function", "feature", "features", "frontend", "framework",
        "component", "configuration", "context", "controller", "chrome", "check", "click",
        "interface", "implementation", "input", "install", "integration", "issue",
        "performance", "platform", "plugin", "project", "process",
        "developer", "database", "default", "design", "document",
        "application", "architecture", "assistant", "autocomplete", "async",
        "window", "workflow", "workspace",
        "english", "environment", "error", "event", "update", "browser"
    ]

    /// English 2-Word (Bigram) Contextual Collocations for natural English phrase prediction.
    public static let englishBigramCollocations: [String: [String]] = [
        "i can": ["do it", "help", "see"],
        "i can't": ["do it", "believe", "wait"],
        "can do": ["it", "this", "that"],
        "do it": ["now", "today", "again"],
        "thank you": ["so much", "very much", "for"],
        "looking forward": ["to", "to hearing", "to seeing"],
        "let me": ["know", "check", "help"],
        "how to": ["use", "fix", "do it"]
    ]

    /// English Single-Word (Unigram) Next-word collocations following a completed English word.
    public static let englishNextWordCollocations: [String: [String]] = [
        "i": ["can", "will", "think", "want"],
        "can": ["do", "do it", "help", "you"],
        "can't": ["do", "do it", "wait"],
        "do": ["it", "this", "that"],
        "it": ["is", "now", "today", "works"],
        "please": ["help", "check", "let me know"],
        "thank": ["you", "you so much"]
    ]

    /// Missing bridge words when the cursor is placed between two words (e.g. "không | thị" -> "hiển").
    public static let missingBridgeWords: [String: String] = [
        "không|thị": "hiển",
        "hiển|được": "thị",
        "xin|ơn": "cảm",
        "chưa|value": "đạt",
        "chưa|yêu": "đạt",
        "bị|hiển": "lỗi",
        "hỗ|tiếng": "trợ",
        "thực|có": "sự",
        "thực|co": "sự",
        "thực|đang": "sự",
        "hoạt|tốt": "động",
        "kịch|verify": "bản",
        "kịch|test": "bản",
        "kịch|kiểm": "bản"
    ]

    /// Resolves missing bridge words between two words, handling direct pairs, shorthand/teencode, and unsigned variations.
    public static func resolveBridgeWord(left: String, right: String) -> String? {
        let cleanLeft = left.trimmingCharacters(in: .punctuationCharacters).lowercased()
        let cleanRight = right.trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard !cleanLeft.isEmpty, !cleanRight.isEmpty else { return nil }

        // 1. Direct match
        if let direct = missingBridgeWords["\(cleanLeft)|\(cleanRight)"] {
            return direct
        }

        // 2. Expand shorthand / teencode / typos
        let normLeft = TeencodeDictionary.mapping[cleanLeft] ?? instantWordFixes[cleanLeft] ?? cleanLeft
        let normRight = TeencodeDictionary.mapping[cleanRight] ?? instantWordFixes[cleanRight] ?? cleanRight
        if let expanded = missingBridgeWords["\(normLeft.lowercased())|\(normRight.lowercased())"] {
            return expanded
        }

        // 3. Unsigned / diacritic-stripped matching
        let strippedLeft = stripDiacritics(cleanLeft)
        let strippedRight = stripDiacritics(cleanRight)
        for (pair, bridge) in missingBridgeWords {
            let parts = pair.split(separator: "|")
            guard parts.count == 2 else { continue }
            let pLeft = String(parts[0])
            let pRight = String(parts[1])
            if (pLeft == normLeft.lowercased() || stripDiacritics(pLeft) == strippedLeft) &&
               (pRight == normRight.lowercased() || stripDiacritics(pRight) == strippedRight) {
                return bridge
            }
        }
        return nil
    }

    /// Evaluates how urgently the input sentence needs typo correction, diacritic restoration, or System Prompt alignment.
    public static func evaluateSeverity(
        rawSentence: String,
        polishedSentence: String = "",
        tone: PolishTone = .natural,
        preset: SystemPromptPreset = OnDeviceAIEngine.activeSystemPromptPreset,
        customPrompt: String = OnDeviceAIEngine.customSystemPrompt
    ) -> SuggestionSeverity {
        let trimmed = rawSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .normal }

        let effectiveTone: PolishTone = {
            switch preset {
            case .formalEmail: return .polite
            case .concise: return .concise
            default: return tone
            }
        }()

        let polished = polishedSentence.isEmpty
            ? VietnameseTextPolisher.polish(trimmed, tone: effectiveTone)
            : polishedSentence
        let normalizedInput = VietnameseTextPolisher.normalizePunctuation(trimmed)

        let rawTokens = normalizedInput
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }
        let polishedTokens = polished
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }

        guard !rawTokens.isEmpty else { return .normal }

        let lowerPrompt = customPrompt.lowercased()
        let enforcesFormal = preset == .formalEmail ||
            lowerPrompt.contains("trang trọng") ||
            lowerPrompt.contains("lịch sự") ||
            lowerPrompt.contains("email") ||
            lowerPrompt.contains("không dùng từ viết tắt") ||
            lowerPrompt.contains("teencode")
        let enforcesConcise = preset == .concise ||
            lowerPrompt.contains("ngắn gọn") ||
            lowerPrompt.contains("súc tích") ||
            lowerPrompt.contains("rút gọn")

        // 1. Check System Prompt explicit rule violations
        if enforcesFormal {
            let informalOrTeencode: Set<String> = [
                "ko", "k", "dc", "đc", "mn", "mik", "mk", "vs", "ntn", "j", "cx", "trc", "bh", "hnay", "mày", "tao"
            ]
            if rawTokens.contains(where: { informalOrTeencode.contains($0) }) {
                return .high
            }
        }
        if enforcesConcise {
            let lowerRaw = normalizedInput.lowercased()
            for filler in VietnameseTextPolisher.fillerPhrases where lowerRaw.contains(filler) {
                return .high
            }
            if rawTokens.contains(where: { VietnameseTextPolisher.singleWordFillers.contains($0) }) {
                return .high
            }
        }

        // 2. Count token-level differences between rawTokens and polishedTokens
        var changedTokenCount = abs(polishedTokens.count - rawTokens.count)
        let minCount = min(rawTokens.count, polishedTokens.count)
        for i in 0..<minCount {
            if rawTokens[i] != polishedTokens[i] {
                changedTokenCount += 1
            }
        }

        // Also count punctuation spacing repairs (" . " -> ". ") and mid-sentence capitalization fixes ("cho english và tiếng việt" -> "Cho English và tiếng Việt")
        let exactRawWords = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let exactPolWords = polished.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if changedTokenCount < 2 {
            var caseOrPunctChanges = abs(exactPolWords.count - exactRawWords.count)
            let exactMin = min(exactRawWords.count, exactPolWords.count)
            for i in 0..<exactMin {
                if i == 0 {
                    if lowercasingFirstChar(exactRawWords[0]) != lowercasingFirstChar(exactPolWords[0]) {
                        caseOrPunctChanges += 1
                    }
                } else if exactRawWords[i] != exactPolWords[i] {
                    caseOrPunctChanges += 1
                }
            }
            changedTokenCount = max(changedTokenCount, caseOrPunctChanges)
        }

        // Check missing bridge words (dropped word between two words)
        if rawTokens.count >= 2 {
            for i in 0..<(rawTokens.count - 1) {
                let pair = "\(rawTokens[i])|\(rawTokens[i + 1])"
                if missingBridgeWords[pair] != nil {
                    changedTokenCount = max(changedTokenCount, 2)
                }
            }
        }

        if changedTokenCount >= 2 {
            return .high
        }
        if changedTokenCount == 1 || hasMeaningfulPolishChange(raw: trimmed, polished: polished) {
            return .moderate
        }
        // Single-word check if only 1 word is typed
        if let first = rawTokens.first {
            if instantWordFixes[first] != nil ||
               TeencodeDictionary.mapping[first] != nil ||
               TeencodeDictionary.englishMapping[first] != nil ||
               TeencodeDictionary.normalizeEnglishRepeatedLetters(first) != nil {
                return .moderate
            }
        }
        return .normal
    }

    private static func lowercasingFirstChar(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// Returns true if `polished` makes a meaningful change to `raw` beyond merely capitalizing the very first character of the text.
    public static func hasMeaningfulPolishChange(raw: String, polished: String) -> Bool {
        let cleanRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPol = polished.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRaw.isEmpty, !cleanPol.isEmpty else { return false }
        let normalizedRaw = VietnameseTextPolisher.normalizePunctuation(cleanRaw)
        if cleanPol.lowercased() != normalizedRaw.lowercased() {
            return true
        }
        return lowercasingFirstChar(cleanPol) != lowercasingFirstChar(cleanRaw)
    }

    /// Promotes the full-sentence `.aiPolish` suggestion (`✨`) to Slot #1 (`⇥` / `⇥⇥`) when `severity == .high`
    /// or when `severity == .moderate` and Slot #1 is only a generic `.wordCompletion`.
    public static func prioritizeForSeverity(
        _ items: [SuggestionItem],
        severity: SuggestionSeverity
    ) -> [SuggestionItem] {
        guard let aiIndex = items.firstIndex(where: { $0.kind == .aiPolish }),
              aiIndex > 0 else {
            return items
        }
        let shouldPromote = (severity == .high) ||
            (severity == .moderate && items.first?.kind == .wordCompletion)
        guard shouldPromote else { return items }
        var reordered = items
        let aiItem = reordered.remove(at: aiIndex)
        reordered.insert(aiItem, at: 0)
        return reordered
    }

    /// Generates up to 3 high-value contextual suggestions based on current word, raw buffer, live sentence words, and full box text.
    public static func suggest(
        currentWord: String,
        rawWord: String,
        sentenceWords: [String],
        tone: PolishTone = .natural,
        fullSentenceText: String = "",
        wordAfterCursor: String = "",
        promoteAIPolishOnHighSeverity: Bool = false
    ) -> [SuggestionItem] {
        var items: [SuggestionItem] = []
        var seen: Set<String> = []

        let trimmedCurrent = currentWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRaw = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateFullSentence: String = {
            let cleanFull = fullSentenceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanFull.isEmpty { return cleanFull }
            return (sentenceWords + (trimmedCurrent.isEmpty ? [] : [trimmedCurrent])).joined(separator: " ")
        }()
        let cleanCandidateLower = candidateFullSentence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()

        func add(_ item: SuggestionItem) {
            let key = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty,
                  key != trimmedCurrent.lowercased(),
                  !seen.contains(key),
                  items.count < 3 else { return }

            // Prevent suggesting a phrase or next-word that already exists at the end of the sentence
            if item.kind != .aiPolish && !item.replaceLastCompletedWord {
                if cleanCandidateLower == key || cleanCandidateLower.hasSuffix(" " + key) {
                    return
                }
            }
            seen.insert(key)
            items.append(item)
        }

        let effectiveTone: PolishTone = {
            switch OnDeviceAIEngine.activeSystemPromptPreset {
            case .formalEmail: return .polite
            case .concise: return .concise
            default: return tone
            }
        }()
        let isEnglishContext = VietnameseTextPolisher.isPrimarilyEnglish(candidateFullSentence)
        let polishedFull = VietnameseTextPolisher.polish(candidateFullSentence, tone: effectiveTone)
        let sentenceSeverity = evaluateSeverity(
            rawSentence: candidateFullSentence,
            polishedSentence: polishedFull,
            tone: effectiveTone
        )

        // CASE 1: User is actively typing or cursor is on a word (e.g. "duoc|" inside "không  thị duoc| hết text" or "cannn|" inside "i cannn|")
        if !trimmedCurrent.isEmpty {
            let lowerCurrent = trimmedCurrent.lowercased()
            let lowerRaw = trimmedRaw.lowercased()
            let asciiCurrent = stripDiacritics(lowerCurrent)

            // 1A. Tier 1: Contextual Collocation Typo Fix + Custom Macro / Teencode / Shorthand / Typo instant expansion
            let contextualFix = isEnglishContext ? nil : resolveContextualWordFix(
                prevWord: sentenceWords.last,
                currentWord: lowerCurrent,
                wordAfterCursor: wordAfterCursor
            )
            let directVnExpanded: String? = {
                if let macro = CustomMacroRegistry.shared.lookup(lowerCurrent) ?? CustomMacroRegistry.shared.lookup(lowerRaw) {
                    return macro
                }
                if isEnglishContext {
                    // In English sentence context, only allow ASCII English typo fixes from instantWordFixes (never Vietnamese diacritic homographs like "day"->"đây", "that"->"thật")
                    if let fix = instantWordFixes[lowerCurrent] ?? instantWordFixes[lowerRaw],
                       fix.unicodeScalars.allSatisfy({ $0.value <= 127 }) {
                        return fix
                    }
                    return nil
                }
                return TeencodeDictionary.mapping[lowerCurrent]
                    ?? TeencodeDictionary.mapping[lowerRaw]
                    ?? instantWordFixes[lowerCurrent]
                    ?? instantWordFixes[lowerRaw]
            }()

            if let primaryFix = contextualFix ?? directVnExpanded {
                add(SuggestionItem(
                    text: primaryFix,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: true,
                    targetWordToReplace: trimmedCurrent,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }
            if let enExpanded = TeencodeDictionary.englishMapping[lowerCurrent]
                ?? TeencodeDictionary.englishMapping[lowerRaw]
                ?? TeencodeDictionary.normalizeEnglishRepeatedLetters(lowerCurrent)
                ?? TeencodeDictionary.normalizeEnglishRepeatedLetters(lowerRaw) {
                add(SuggestionItem(
                    text: enExpanded,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: true,
                    targetWordToReplace: trimmedCurrent,
                    severity: max(.moderate, sentenceSeverity)
                ))
                // If user typed "cann" / "cannn", also offer "can't" as a helpful contraction alternative
                if enExpanded.lowercased() == "can" {
                    add(SuggestionItem(
                        text: "can't",
                        kind: .teencodeExpansion,
                        replaceCurrentWord: true,
                        targetWordToReplace: trimmedCurrent,
                        severity: .moderate
                    ))
                }
            }

            // 1B. Tier 2: Full-Sentence / Full-Box Repair & Polish (up to 500 words across sentences & paragraphs)
            let fullWordsCount = candidateFullSentence.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            if fullWordsCount >= 2 && fullWordsCount <= 500 {
                if !polishedFull.isEmpty && hasMeaningfulPolishChange(raw: candidateFullSentence, polished: polishedFull) {
                    add(SuggestionItem(
                        text: polishedFull,
                        kind: .aiPolish,
                        replaceCurrentWord: false,
                        severity: max(.moderate, sentenceSeverity)
                    ))
                }
            }

            // If contextualFix was used as primary Tier 1, also offer directVnExpanded (e.g. "cau" after "không" -> #1 "dấu", #2 ✨ sentence, #3 "câu")
            if contextualFix != nil, let secondaryFix = directVnExpanded {
                add(SuggestionItem(
                    text: secondaryFix,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: true,
                    targetWordToReplace: trimmedCurrent,
                    severity: .moderate
                ))
            }

            // Bridge word check when caret is touching the left word (e.g. "không| thị" -> "hiển")
            if !isEnglishContext,
               !wordAfterCursor.isEmpty,
               let bridge = resolveBridgeWord(left: trimmedCurrent, right: wordAfterCursor) {
                add(SuggestionItem(
                    text: bridge,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: false,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }

            // 1C. Contextual Bigram/Unigram Collocation Prefix Match
            if isEnglishContext {
                if sentenceWords.count >= 2 {
                    let lastTwo = sentenceWords.suffix(2).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }.joined(separator: " ")
                    if let biCands = englishBigramCollocations[lastTwo] {
                        for cand in biCands where cand.lowercased().hasPrefix(lowerCurrent) {
                            add(SuggestionItem(text: cand, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                        }
                    }
                }
                if let prevWord = sentenceWords.last?.lowercased().trimmingCharacters(in: .punctuationCharacters),
                   let nextCandidates = englishNextWordCollocations[prevWord] {
                    for cand in nextCandidates where cand.lowercased().hasPrefix(lowerCurrent) {
                        add(SuggestionItem(text: cand, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                    }
                }
            } else {
                if sentenceWords.count >= 2 {
                    let lastTwo = sentenceWords.suffix(2).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }.joined(separator: " ")
                    if let biCands = bigramCollocations[lastTwo] {
                        for cand in biCands {
                            let candLower = cand.lowercased()
                            if candLower.hasPrefix(lowerCurrent) || stripDiacritics(candLower).hasPrefix(asciiCurrent) {
                                add(SuggestionItem(text: cand, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                            }
                        }
                    }
                }
                if let prevWord = sentenceWords.last?.lowercased().trimmingCharacters(in: .punctuationCharacters),
                   let nextCandidates = nextWordCollocations[prevWord] {
                    for cand in nextCandidates {
                        let candLower = cand.lowercased()
                        if candLower.hasPrefix(lowerCurrent) || stripDiacritics(candLower).hasPrefix(asciiCurrent) {
                            add(SuggestionItem(text: cand, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                        }
                    }
                }

                // 1D. Vietnamese exact-diacritic prefix match (prioritized over English prefix matches when not in English sentence context)
                for phrase in vietnamesePhrases {
                    let cleanPhrase = phrase.trimmingCharacters(in: .whitespaces)
                    let lowerPhrase = cleanPhrase.lowercased()
                    if lowerPhrase.hasPrefix(lowerCurrent) && lowerPhrase != lowerCurrent {
                        add(SuggestionItem(text: cleanPhrase, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                    }
                }

                // 1E. Vietnamese ASCII/stripped-diacritic prefix match (e.g. "hien" -> "hiển thị", "chua" -> "chưa đạt", "va" -> "vào")
                if items.count < 3 {
                    for phrase in vietnamesePhrases {
                        let cleanPhrase = phrase.trimmingCharacters(in: .whitespaces)
                        let strippedPhrase = stripDiacritics(cleanPhrase.lowercased())
                        if strippedPhrase.hasPrefix(asciiCurrent) && cleanPhrase.lowercased() != lowerCurrent {
                            add(SuggestionItem(text: cleanPhrase, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                        }
                    }
                }
            }

            // 1F. English prefix match
            if asciiCurrent.count >= 2 {
                for enWord in englishCompletions {
                    let lowerEn = enWord.lowercased()
                    if (lowerEn.hasPrefix(lowerRaw) || lowerEn.hasPrefix(asciiCurrent)) && lowerEn != lowerCurrent {
                        add(SuggestionItem(text: enWord, kind: .wordCompletion, replaceCurrentWord: true, targetWordToReplace: trimmedCurrent, severity: sentenceSeverity))
                    }
                }
            }

            return promoteAIPolishOnHighSeverity
                ? prioritizeForSeverity(items, severity: sentenceSeverity)
                : items
        }

        // CASE 2: Cursor is after a space (either at end of sentence or in a gap between two words like "không | thị" or "i cannn do it ")
        if let lastWord = sentenceWords.last {
            let cleanLast = lastWord.trimmingCharacters(in: .punctuationCharacters)
            let lowerLast = cleanLast.lowercased()
            let lowerAfter = wordAfterCursor.trimmingCharacters(in: .punctuationCharacters).lowercased()

            // 2A. Missing bridge word in gap between two words (e.g. "không | thị" -> "⚡ hiển", "khong | thi" -> "⚡ hiển")
            if !isEnglishContext,
               !lowerAfter.isEmpty,
               let bridge = resolveBridgeWord(left: lastWord, right: lowerAfter) {
                add(SuggestionItem(
                    text: bridge,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: false,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }

            // 2B. If the just-completed word was a contextual typo, custom macro, teencode, or English/Vietnamese typo (e.g. "không cau ", "ko ", "i cannn ", "i dont "),
            // offer a 1-click fix for THAT word first!
            let prevBeforeLast = sentenceWords.dropLast().last
            let contextualLastFix = isEnglishContext ? nil : resolveContextualWordFix(
                prevWord: prevBeforeLast,
                currentWord: lowerLast,
                wordAfterCursor: lowerAfter
            )
            let wordFixCandidate: String? = {
                if let macro = CustomMacroRegistry.shared.lookup(lowerLast) {
                    return macro
                }
                if isEnglishContext {
                    if let enFix = TeencodeDictionary.englishMapping[lowerLast] ?? TeencodeDictionary.normalizeEnglishRepeatedLetters(lowerLast) {
                        return enFix
                    }
                    if let asciiFix = instantWordFixes[lowerLast], asciiFix.unicodeScalars.allSatisfy({ $0.value <= 127 }) {
                        return asciiFix
                    }
                    return nil
                }
                return contextualLastFix
                    ?? TeencodeDictionary.mapping[lowerLast]
                    ?? instantWordFixes[lowerLast]
                    ?? TeencodeDictionary.englishMapping[lowerLast]
                    ?? TeencodeDictionary.normalizeEnglishRepeatedLetters(lowerLast)
            }()

            if let wordFix = wordFixCandidate,
               wordFix.lowercased() != lowerLast {
                add(SuggestionItem(
                    text: wordFix,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: false,
                    replaceLastCompletedWord: true,
                    targetWordToReplace: cleanLast,
                    severity: max(.moderate, sentenceSeverity)
                ))
                if isEnglishContext && wordFix.lowercased() == "can" {
                    add(SuggestionItem(
                        text: "can't",
                        kind: .teencodeExpansion,
                        replaceCurrentWord: false,
                        replaceLastCompletedWord: true,
                        targetWordToReplace: cleanLast,
                        severity: .moderate
                    ))
                }
            }

            // 2C. Tier 2: Full-Sentence / Full-Box Repair & Polish (up to 500 words across sentences & paragraphs)
            let fullWordsCount = candidateFullSentence.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            if fullWordsCount >= 2 && fullWordsCount <= 500 {
                if !polishedFull.isEmpty && hasMeaningfulPolishChange(raw: candidateFullSentence, polished: polishedFull) {
                    add(SuggestionItem(
                        text: polishedFull,
                        kind: .aiPolish,
                        replaceCurrentWord: false,
                        severity: max(.moderate, sentenceSeverity)
                    ))
                    if isEnglishContext && candidateFullSentence.range(of: "(?i)\\bcann+\\b", options: .regularExpression) != nil {
                        let cantVariant = polishedFull.replacingOccurrences(of: "(?i)\\bcan\\b", with: "can't", options: .regularExpression)
                        if cantVariant.lowercased() != polishedFull.lowercased() {
                            add(SuggestionItem(
                                text: cantVariant,
                                kind: .aiPolish,
                                replaceCurrentWord: false,
                                severity: .moderate
                            ))
                        }
                    }
                }
            }

            // 2D. Bigram Next-Word Collocations
            if sentenceWords.count >= 2 {
                let lastTwo = sentenceWords.suffix(2)
                    .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                    .joined(separator: " ")
                let biMap = isEnglishContext ? englishBigramCollocations : bigramCollocations
                if let biCands = biMap[lastTwo] {
                    for cand in biCands {
                        add(SuggestionItem(text: cand, kind: .nextWord, replaceCurrentWord: false, severity: sentenceSeverity))
                    }
                }
            }

            // 2E. Unigram Next-Word Collocations
            let uniMap = isEnglishContext ? englishNextWordCollocations : nextWordCollocations
            if let nextCandidates = uniMap[lowerLast] {
                for cand in nextCandidates {
                    add(SuggestionItem(text: cand, kind: .nextWord, replaceCurrentWord: false, severity: sentenceSeverity))
                }
            }
        }

        return promoteAIPolishOnHighSeverity
            ? prioritizeForSeverity(items, severity: sentenceSeverity)
            : items
    }

    /// Strips Vietnamese diacritics for fuzzy prefix matching.
    public static func stripDiacritics(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
        return folded
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
    }
}
