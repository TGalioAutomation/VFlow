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
        "su": "sử dụng",
        "dung": "dụng",
        "texxt": "text",
        "tetx": "text",
        "sugget": "suggest",
        "sugest": "suggest",
        "vaule": "value"
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
        "that|su": "sự",
        "that|sư": "sự",
        "thaat|sư": "sự",
        "thaat|su": "sự",
        "thực|sư": "sự",
        "thực|su": "sự",
        "thuc|sư": "sự",
        "thuc|su": "sự",
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
        "the|nao": "nào"
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

        // Check nextWordCollocations for unsigned/wrong-tone match or 1-key typo match
        if !isCauException, let collocations = nextWordCollocations[normPrev] ?? nextWordCollocations[validPrev] {
            let strippedCurrent = stripDiacritics(cleanCurrent)
            for cand in collocations where !cand.contains(" ") {
                let candLower = cand.lowercased()
                let strippedCand = stripDiacritics(candLower)
                if strippedCand == strippedCurrent && candLower != cleanCurrent {
                    return cand
                }
            }
            // If currentWord is pure ASCII of length >= 3, check 1-char edit distance against collocation followers
            let isPureASCII = cleanCurrent.unicodeScalars.allSatisfy { $0.value <= 127 }
            if isPureASCII && cleanCurrent.count >= 3 {
                for cand in collocations where !cand.contains(" ") {
                    let candLower = cand.lowercased()
                    let strippedCand = stripDiacritics(candLower)
                    if strippedCand.count == cleanCurrent.count && asciiEditDistance(strippedCand, cleanCurrent) == 1 {
                        return cand
                    }
                }
            }
        }
        return nil
    }

    /// High-frequency Vietnamese words & compound phrases for instant prefix completion.
    public static let vietnamesePhrases: [String] = [
        "hiển thị", "hiển thị đầy đủ", "hiển thị được", "hiệu ứng", "hiện tại", "hệ thống", "hỗ trợ", "hoàn thành", "hoạt động", "hướng dẫn", "hết", "hết text",
        "không", "không hiển thị", "không được", "không thể", "không biết", "khắc phục", "khởi động", "kiểm tra", "kiểm thử", "kết quả", "kết nối",
        "được", "được hết", "đạt", "đạt yêu cầu", "đã", "đang", "đồng bộ", "đóng gói", "đường dẫn", "đưa ra",
        "chưa", "chưa đạt", "chưa được", "chưa ổn", "chức năng", "chương trình", "chỉnh sửa", "chính xác", "chuyển đổi", "chạy",
        "phần", "phần gợi ý", "phần hiển thị", "phần mềm", "phát triển", "phiên bản", "phím tắt", "phản hồi",
        "bị", "bị lỗi", "bị sai", "bình thường", "bổ sung", "bắt đầu", "bây giờ", "bàn phím", "báo cáo",
        "lỗi", "lỗi hiển thị", "làm mượt", "lập trình", "lựa chọn", "luôn",
        "gõ", "gõ tiếng Việt", "gợi ý", "gợi ý từ", "giải pháp", "giúp", "giao diện",
        "cần", "cần hỗ trợ", "cập nhật", "cài đặt", "cấu hình", "cảm ơn", "cải thiện", "công nghệ",
        "tiếng Việt", "tiếng Anh", "tiếp tục", "tiến độ", "tính năng", "tự động", "tối ưu", "tốt", "tạo", "tìm kiếm",
        "xử lý", "xác nhận", "xây dựng", "xem", "xong", "xin cảm ơn", "xin chào",
        "và", "vào", "vấn đề", "vẫn", "với", "về", "vậy", "văn bản", "vui lòng",
        "ứng dụng", "ưu tiên",
        "người dùng", "nguyên nhân", "nhanh chóng", "như thế nào", "nhưng", "nhiều", "nội dung",
        "mặc định", "môi trường", "mới", "mở", "màn hình",
        "sử dụng", "sửa lỗi", "sẵn sàng",
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
        "thực tế": ["có", "đang", "hoạt động"]
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
        "cần": ["hỗ trợ", "xử lý", "kiểm tra"],
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
        "gợi": ["ý", "ý từ", "ý thông minh"]
    ]

    /// High-frequency English technical & everyday words for prefix completion.
    public static let englishCompletions: [String] = [
        "suggest", "suggestion", "suggestions", "support", "system", "settings", "service", "server", "screen", "search", "status",
        "value", "values", "validation", "version", "view", "vietnamese",
        "text", "textarea", "testing", "terminal", "typescript", "token",
        "function", "feature", "features", "frontend", "framework",
        "component", "configuration", "context", "controller",
        "interface", "implementation", "input", "install", "integration",
        "performance", "platform", "plugin", "project", "process",
        "developer", "database", "default", "design", "document",
        "application", "architecture", "assistant", "autocomplete", "async",
        "window", "workflow", "workspace",
        "english", "environment", "error", "event"
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
        "hoạt|tốt": "động"
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
        if changedTokenCount == 1 || polished.lowercased() != normalizedInput.lowercased() {
            return .moderate
        }
        // Single-word check if only 1 word is typed
        if let first = rawTokens.first {
            if instantWordFixes[first] != nil || TeencodeDictionary.mapping[first] != nil {
                return .moderate
            }
        }
        return .normal
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

        func add(_ item: SuggestionItem) {
            let key = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty,
                  key != currentWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !seen.contains(key),
                  items.count < 3 else { return }
            seen.insert(key)
            items.append(item)
        }

        let trimmedCurrent = currentWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRaw = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateFullSentence: String = {
            let cleanFull = fullSentenceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanFull.isEmpty { return cleanFull }
            return (sentenceWords + (trimmedCurrent.isEmpty ? [] : [trimmedCurrent])).joined(separator: " ")
        }()

        let effectiveTone: PolishTone = {
            switch OnDeviceAIEngine.activeSystemPromptPreset {
            case .formalEmail: return .polite
            case .concise: return .concise
            default: return tone
            }
        }()
        let polishedFull = VietnameseTextPolisher.polish(candidateFullSentence, tone: effectiveTone)
        let sentenceSeverity = evaluateSeverity(
            rawSentence: candidateFullSentence,
            polishedSentence: polishedFull,
            tone: effectiveTone
        )

        // CASE 1: User is actively typing or cursor is on a word (e.g. "duoc|" inside "không  thị duoc| hết text")
        if !trimmedCurrent.isEmpty {
            let lowerCurrent = trimmedCurrent.lowercased()
            let lowerRaw = trimmedRaw.lowercased()
            let asciiCurrent = stripDiacritics(lowerCurrent)

            // 1A. Tier 1: Contextual Collocation Typo Fix + Custom Macro / Teencode / Shorthand / Typo instant expansion
            let contextualFix = resolveContextualWordFix(
                prevWord: sentenceWords.last,
                currentWord: lowerCurrent,
                wordAfterCursor: wordAfterCursor
            )
            let directVnExpanded = CustomMacroRegistry.shared.lookup(lowerCurrent)
                ?? CustomMacroRegistry.shared.lookup(lowerRaw)
                ?? TeencodeDictionary.mapping[lowerCurrent]
                ?? TeencodeDictionary.mapping[lowerRaw]
                ?? instantWordFixes[lowerCurrent]
                ?? instantWordFixes[lowerRaw]

            if let primaryFix = contextualFix ?? directVnExpanded {
                add(SuggestionItem(
                    text: primaryFix,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: true,
                    targetWordToReplace: trimmedCurrent,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }
            if let enExpanded = TeencodeDictionary.englishMapping[lowerCurrent] ?? TeencodeDictionary.englishMapping[lowerRaw] {
                add(SuggestionItem(
                    text: enExpanded,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: true,
                    targetWordToReplace: trimmedCurrent,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }

            // 1B. Tier 2: Full-Sentence Repair/Polish if the surrounding sentence has multiple words & issues (e.g. "không  thị duoc hết text" -> "✨ không hiển thị được hết text")
            let fullWordsCount = candidateFullSentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            if fullWordsCount >= 2 && fullWordsCount <= 16 {
                let normalizedInput = VietnameseTextPolisher.normalizePunctuation(candidateFullSentence)
                if !polishedFull.isEmpty && polishedFull.lowercased() != normalizedInput.lowercased() {
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
            if !wordAfterCursor.isEmpty,
               let bridge = resolveBridgeWord(left: trimmedCurrent, right: wordAfterCursor) {
                add(SuggestionItem(
                    text: bridge,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: false,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }

            // 1C. Contextual Bigram/Unigram Collocation Prefix Match (e.g. prev="không", current="hi" -> "hiển thị")
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

            // 1D. Vietnamese exact-diacritic prefix match (prioritized over English prefix matches)
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

            // 1F. English prefix match (evaluated after Vietnamese so English words like "val" don't crowd out "va" -> "vào")
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

        // CASE 2: Cursor is after a space (either at end of sentence or in a gap between two words like "không | thị")
        if let lastWord = sentenceWords.last {
            let cleanLast = lastWord.trimmingCharacters(in: .punctuationCharacters)
            let lowerLast = cleanLast.lowercased()
            let lowerAfter = wordAfterCursor.trimmingCharacters(in: .punctuationCharacters).lowercased()

            // 2A. Missing bridge word in gap between two words (e.g. "không | thị" -> "⚡ hiển", "khong | thi" -> "⚡ hiển")
            if !lowerAfter.isEmpty,
               let bridge = resolveBridgeWord(left: lastWord, right: lowerAfter) {
                add(SuggestionItem(
                    text: bridge,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: false,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }

            // 2B. If the just-completed word was a contextual typo, custom macro, teencode, or typo (e.g. "không cau ", "ko ", "ddwuocj ", "phân "),
            // offer a 1-click fix for THAT word first!
            let prevBeforeLast = sentenceWords.dropLast().last
            let contextualLastFix = resolveContextualWordFix(
                prevWord: prevBeforeLast,
                currentWord: lowerLast,
                wordAfterCursor: lowerAfter
            )
            if let wordFix = contextualLastFix ?? CustomMacroRegistry.shared.lookup(lowerLast) ?? TeencodeDictionary.mapping[lowerLast] ?? instantWordFixes[lowerLast],
               wordFix.lowercased() != lowerLast {
                add(SuggestionItem(
                    text: wordFix,
                    kind: .teencodeExpansion,
                    replaceCurrentWord: false,
                    replaceLastCompletedWord: true,
                    targetWordToReplace: cleanLast,
                    severity: max(.moderate, sentenceSeverity)
                ))
            }

            // 2C. Tier 2: Full-Sentence Repair/Polish (e.g. "không  thị duoc hết text" -> "✨ không hiển thị được hết text")
            let fullWordsCount = candidateFullSentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            if fullWordsCount >= 2 && fullWordsCount <= 16 {
                let normalizedInput = VietnameseTextPolisher.normalizePunctuation(candidateFullSentence)
                if !polishedFull.isEmpty && polishedFull.lowercased() != normalizedInput.lowercased() {
                    add(SuggestionItem(
                        text: polishedFull,
                        kind: .aiPolish,
                        replaceCurrentWord: false,
                        severity: max(.moderate, sentenceSeverity)
                    ))
                }
            }

            // 2D. Bigram Next-Word Collocations (e.g. "không hiển" -> "thị", "hiển thị" -> "được", "chưa đạt" -> "value")
            if sentenceWords.count >= 2 {
                let lastTwo = sentenceWords.suffix(2)
                    .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                    .joined(separator: " ")
                if let biCands = bigramCollocations[lastTwo] {
                    for cand in biCands {
                        add(SuggestionItem(text: cand, kind: .nextWord, replaceCurrentWord: false, severity: sentenceSeverity))
                    }
                }
            }

            // 2E. Unigram Next-Word Collocations
            if let nextCandidates = nextWordCollocations[lowerLast] {
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
