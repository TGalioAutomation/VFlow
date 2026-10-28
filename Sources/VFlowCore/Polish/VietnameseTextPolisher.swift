import Foundation

/// Fast offline rule-based polisher for spoken & typed Vietnamese and English (Bilingual) text.
public struct VietnameseTextPolisher: Sendable {
    /// Common spoken Vietnamese & English hesitation and filler phrases.
    public static let fillerPhrases: [String] = [
        "kiểu như là",
        "thì là mà",
        "nói chung là",
        "à ừm",
        "à ưm",
        "ờ thì",
        "ờ m",
        "à thì",
        "kiểu là",
        "tự dưng kiểu",
        "kiểu kiểu vậy",
        "đại loại là",
        "you know",
        "i mean",
        "kind of",
        "sort of",
        "uh um",
        "um uh"
    ]

    /// Single-word fillers when standing alone or at phrase boundaries (VI + EN).
    public static let singleWordFillers: Set<String> = [
        "à", "ừm", "ờ", "ưm", "ơ", "hả", "nè",
        "uh", "um", "umm", "uhh", "er", "erm", "hmm", "basically", "literally"
    ]

    /// Detects whether a text string is primarily English (no Vietnamese diacritics/teencode and contains English words).
    public static func isPrimarilyEnglish(_ text: String) -> Bool {
        let tokens = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return false }

        // If any token contains Vietnamese diacritics or known Vietnamese teencode, treat as Vietnamese/Bilingual
        let vnMarkers: Set<String> = ["ko", "đc", "dc", "ntn", "mn", "cx", "vs", "kb", "trc", "bh", "hnay", "mik", "mk"]
        for tok in tokens {
            if vnMarkers.contains(tok) { return false }
            for ch in tok {
                if ch.unicodeScalars.contains(where: { $0.value > 127 }) {
                    return false
                }
            }
        }

        let enMatches = tokens.filter {
            SmartEnglishDetector.commonEnglishWords.contains($0) ||
            SmartEnglishDetector.contextualEnglishHomographs.contains($0) ||
            TeencodeDictionary.englishMapping[$0] != nil ||
            ["i", "you", "he", "she", "it", "we", "they", "the", "a", "an", "to", "of", "in", "on", "at", "go", "time", "ready", "work", "home", "please", "help", "fix", "bug", "how", "can", "could", "would"].contains($0)
        }.count

        return enMatches * 2 >= tokens.count
    }

    /// Polishes raw text according to the selected tone (supporting both Vietnamese and English).
    public static func polish(_ text: String, tone: PolishTone = .natural) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let isEnglish = isPrimarilyEnglish(trimmed)

        // Step 1: Remove filler phrases
        var cleaned = removeFillers(trimmed)

        // Step 2: Expand teencode / English shorthand
        cleaned = isEnglish ? expandEnglishShorthand(cleaned) : expandTeencode(cleaned)

        // Step 3: Normalize whitespace and punctuation
        cleaned = normalizePunctuation(cleaned)

        // Step 4: Apply tone-specific stylistic transformations
        if isEnglish {
            switch tone {
            case .natural:
                return applyEnglishNaturalTone(cleaned)
            case .polite:
                return applyEnglishPoliteTone(cleaned)
            case .concise:
                return applyEnglishConciseTone(cleaned)
            }
        } else {
            switch tone {
            case .natural:
                return applyNaturalTone(cleaned)
            case .polite:
                return applyPoliteTone(cleaned)
            case .concise:
                return applyConciseTone(cleaned)
            }
        }
    }

    // MARK: - Cleaning Steps

    /// Removes filler phrases and interjections.
    public static func removeFillers(_ text: String) -> String {
        var result = text

        // 1. Remove multi-word filler phrases (case-insensitive)
        for phrase in fillerPhrases {
            let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // 2. Remove leading/isolated single-word fillers
        let tokens = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var filteredTokens: [String] = []

        for (idx, token) in tokens.enumerated() {
            let lower = token.lowercased().trimmingCharacters(in: .punctuationCharacters)
            // Filter if it's a known hesitation word at start or followed by comma
            if singleWordFillers.contains(lower) {
                if idx == 0 || token.hasSuffix(",") || token.hasSuffix("...") {
                    continue
                }
            }
            filteredTokens.append(token)
        }

        return filteredTokens.joined(separator: " ")
    }

    /// Common typo & unsigned Vietnamese token repairs when polishing Vietnamese text.
    public static let typoTokenFixes: [String: String] = [
        "ddwuocj": "được",
        "dduwocj": "được",
        "duoc": "được",
        "dduoc": "được",
        "khoog": "không",
        "khoong": "không",
        "khong": "không",
        "heets": "hết",
        "het": "hết",
        "ddansh": "đánh",
        "tot": "tốt",
        "toot": "tốt",
        "hoat": "hoạt",
        "thuc": "thực",
        "thaat": "thật",
        "that": "thật",
        "viec": "việc",
        "toi": "tôi",
        "tooi": "tôi",
        "dang": "đang",
        "ddang": "đang",
        "thu": "thử",
        "tieng": "tiếng",
        "viet": "Việt",
        "dau": "dấu",
        "chua": "chưa",
        "chuan": "chuẩn",
        "nghia": "nghĩa",
        "nhung": "nhưng",
        "nguoi": "người",
        "truoc": "trước",
        "phai": "phải",
        "biet": "biết",
        "muon": "muốn",
        "cung": "cũng",
        "nhieu": "nhiều",
        "luon": "luôn",
        "moi": "mới",
        "loi": "lỗi",
        "nua": "nữa",
        "chang": "chẳng",
        "chac": "chắc",
        "hoac": "hoặc",
        "deu": "đều",
        "vua": "vừa",
        "rat": "rất",
        "kha": "khá",
        "minh": "mình",
        "chung": "chúng",
        "nhat": "nhất",
        "thoi": "thôi",
        "roi": "rồi",
        "vay": "vậy",
        "nay": "này",
        "giua": "giữa",
        "duoi": "dưới",
        "tren": "trên",
        "ngoai": "ngoài",
        "cua": "của",
        "voi": "với",
        "boi": "bởi",
        "texxt": "text",
        "tetx": "text",
        "sugget": "suggest",
        "sugest": "suggest"
    ]

    /// Rejoins shifted-space consonant endings (-ng, -nh, -ch) where Space was pressed 1 character early
    /// (e.g. "đan gkhoong" -> ["đang", "khoong"], "nhưn gkhông" -> ["nhưng", "không"]).
    private static func rejoinShiftedSpaceConsonants(_ rawTokens: [String]) -> [String] {
        guard rawTokens.count >= 2 else { return rawTokens }
        var tokens = rawTokens
        let gFollowConsonants: Set<Character> = ["b", "c", "d", "đ", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x"]
        let hFollowConsonants: Set<Character> = ["b", "c", "d", "đ", "g", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x"]

        for idx in 0..<(tokens.count - 1) {
            let cur = tokens[idx]
            let next = tokens[idx + 1]
            guard cur.count >= 2, next.count >= 3 else { continue }

            let curLower = cur.lowercased()
            let nextLower = next.lowercased()
            guard !SmartEnglishDetector.isEnglishWord(nextLower) else { continue }

            let nextChars = Array(nextLower)
            let firstNext = nextChars[0]
            let secondNext = nextChars[1]

            if curLower.hasSuffix("n") && firstNext == "g" && gFollowConsonants.contains(secondNext) {
                tokens[idx] = cur + String(next.first!)
                tokens[idx + 1] = String(next.dropFirst())
            } else if (curLower.hasSuffix("n") || curLower.hasSuffix("c")) && firstNext == "h" && hFollowConsonants.contains(secondNext) {
                tokens[idx] = cur + String(next.first!)
                tokens[idx + 1] = String(next.dropFirst())
            }
        }
        return tokens
    }

    /// Collapses accidental duplicate vowels in a typo token (e.g. "thaat" -> "that", "khoong" -> "khong").
    private static func collapseAccidentalDoubleVowels(_ word: String) -> String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var chars: [Character] = []
        for ch in word {
            if let last = chars.last, last == ch, vowels.contains(ch) {
                continue
            }
            chars.append(ch)
        }
        return String(chars)
    }

    /// Expands teencode, shorthand tokens, and repairs raw/malformed Telex words.
    public static func expandTeencode(_ text: String) -> String {
        let tokens = rejoinShiftedSpaceConsonants(text.components(separatedBy: " "))
        var expanded: [String] = []
        let telexEngine = VietnameseInputEngine(inputMethod: .telex, tonePlacement: .modern, autoEnglishRestore: true)

        for token in tokens {
            if token.isEmpty { continue }

            // Separate leading/trailing punctuation
            var prefix = ""
            var suffix = ""
            var core = token

            while let first = core.first, first.isPunctuation {
                prefix.append(first)
                core.removeFirst()
            }
            while let last = core.last, last.isPunctuation {
                suffix = String(last) + suffix
                core.removeLast()
            }

            if !core.isEmpty {
                let lowerCore = core.lowercased()
                let collapsedCore = collapseAccidentalDoubleVowels(lowerCore)
                var replaced = CustomMacroRegistry.shared.lookup(lowerCore) ?? TeencodeDictionary.expand(core)
                if replaced == core, let typoFix = typoTokenFixes[lowerCore] ?? typoTokenFixes[collapsedCore] {
                    if let first = core.first, first.isUppercase, let rFirst = typoFix.first {
                        replaced = rFirst.uppercased() + typoFix.dropFirst()
                    } else {
                        replaced = typoFix
                    }
                } else if replaced == core && !SmartEnglishDetector.isEnglishWord(lowerCore) {
                    // Check if token is an un-processed raw Telex string (e.g. "ddwuocj", "tieengs", "vieetj")
                    let reprocessed = telexEngine.reprocess(Array(core))
                    if reprocessed != core && SyllableParser.isValidVietnameseSyllable(raw: core, formatted: reprocessed, isWordBoundary: true) {
                        replaced = reprocessed
                    }
                }
                expanded.append(prefix + replaced + suffix)
            } else {
                expanded.append(token)
            }
        }

        // Contextual pronoun typo repair: "to đang", "t đang", "to thử", "to muốn", "to cần", "to gõ" -> "tôi ..."
        // Exclude preceding noun/adverb antecedents (e.g. "chữ to đang đẹp", "nhà to đang làm", "rất to đang")
        // and do not match English "to go" (e.g. "time to go", "cà phê to go", "ready to go")
        let verbFollowers: Set<String> = [
            "đang", "dang", "đã", "da", "sẽ", "se", "muốn", "muon", "cần", "can",
            "thử", "thu", "gõ", "làm", "lam", "nghĩ", "nghi", "thấy", "thay", "biết", "biet", "vừa", "vua"
        ]
        let nounAdjectiveAntecedents: Set<String> = [
            "chữ", "chu", "nhà", "nha", "xe", "cái", "cai", "con", "quả", "qua", "tiếng", "tieng",
            "loa", "phòng", "phong", "rất", "rat", "khá", "kha", "hơi", "hoi", "quá", "qua", "cực", "cuc"
        ]

        var repairedTokens = expanded
        for idx in 0..<repairedTokens.count {
            let tok = repairedTokens[idx]
            let lower = tok.lowercased()
            if (lower == "to" || lower == "t" || lower == "tooi") && idx + 1 < repairedTokens.count {
                let nextLower = repairedTokens[idx + 1].lowercased()
                let prevLower = idx > 0 ? repairedTokens[idx - 1].lowercased() : nil

                let isPrecededByNounOrAdverb = prevLower.map { nounAdjectiveAntecedents.contains($0) } ?? false
                let isPrecededByEnglish = prevLower.map { SmartEnglishDetector.commonEnglishWords.contains($0) || $0 == "ready" || $0 == "time" || $0 == "want" } ?? false

                if verbFollowers.contains(nextLower) && !isPrecededByNounOrAdverb && !isPrecededByEnglish {
                    repairedTokens[idx] = (tok.first?.isUppercase == true) ? "Tôi" : "tôi"
                }
            }
        }
        var joined = repairedTokens.joined(separator: " ")

        // Contextual multi-word, collocation typo & missing-bridge-word phrase repairs
        let phraseRepairs: [(String, String)] = [
            ("to\\s+go\\s+(?=tiếng|tieng|phím|phim|dấu|dau|chữ|chu)", "tôi gõ "),
            ("phân suggest", "phần suggest"),
            ("phan suggest", "phần suggest"),
            ("không\\s+thị", "không hiển thị"),
            ("xin\\s+ơn", "xin cảm ơn"),
            ("chưa\\s+value", "chưa đạt value"),
            ("chua dat", "chưa đạt"),
            ("bi loi", "bị lỗi"),
            ("khong hien thi", "không hiển thị"),
            ("hien thi", "hiển thị"),
            ("thực\\s+co\\s+đang", "thực sự có đang"),
            ("thực\\s+có\\s+đang", "thực sự có đang"),
            ("thaat\\s+sư", "thật sự"),
            ("thật\\s+sư", "thật sự"),
            ("thaat\\s+sự", "thật sự"),
            ("that\\s+su", "thật sự"),
            ("that\\s+sư", "thật sự"),
            ("thật\\s+su", "thật sự"),
            ("thuc\\s+su", "thực sự"),
            ("thực\\s+sư", "thực sự"),
            ("thuc\\s+sư", "thực sự"),
            ("thực\\s+su", "thực sự"),
            ("co\\s+đang", "có đang"),
            ("hoạt\\s+động\\s+tot", "hoạt động tốt"),
            ("hoat\\s+dong", "hoạt động"),
            ("hoạt\\s+dong", "hoạt động"),
            ("thử\\s+go\\b", "thử gõ"),
            ("thu\\s+go\\b", "thử gõ"),
            ("bộ\\s+go\\b", "bộ gõ"),
            ("bo\\s+go\\b", "bộ gõ"),
            ("go\\s+tiếng", "gõ tiếng"),
            ("go\\s+tieng", "gõ tiếng"),
            ("gõ\\s+sai", "gõ sai"),
            ("go\\s+sai", "gõ sai"),
            ("có\\s+go\\s+sai", "có gõ sai"),
            ("co\\s+go\\s+sai", "có gõ sai"),
            ("co\\s+gõ\\s+sai", "có gõ sai"),
            ("tieng\\s+viet", "tiếng Việt"),
            ("tiếng\\s+viet", "tiếng Việt"),
            ("tieng\\s+anh", "tiếng Anh"),
            ("tiếng\\s+anh", "tiếng Anh"),
            ("không\\s+dau\\b", "không dấu"),
            ("khong\\s+dau\\b", "không dấu"),
            ("không\\s+cau(?!\\s+(có|co|hỏi|hoi|nệ|ne)\\b)\\b", "không dấu"),
            ("khong\\s+cau(?!\\s+(có|co|hỏi|hoi|nệ|ne)\\b)\\b", "không dấu"),
            ("ko\\s+cau(?!\\s+(có|co|hỏi|hoi|nệ|ne)\\b)\\b", "không dấu"),
            ("có\\s+dau\\b", "có dấu"),
            ("co\\s+dau\\b", "có dấu"),
            ("có\\s+cau(?!\\s+(có|co|hỏi|hoi|nệ|ne)\\b)\\b", "có dấu"),
            ("co\\s+cau(?!\\s+(có|co|hỏi|hoi|nệ|ne)\\b)\\b", "có dấu"),
            ("đúng\\s+nghia", "đúng nghĩa"),
            ("dung\\s+nghia", "đúng nghĩa"),
            ("đúng\\s+nghi\\b", "đúng nghĩa"),
            ("chuẩn\\s+hon", "chuẩn hơn"),
            ("chuan\\s+hon", "chuẩn hơn"),
            ("chuan\\s+hơn", "chuẩn hơn"),
            ("tốt\\s+hon", "tốt hơn"),
            ("tot\\s+hon", "tốt hơn"),
            ("tốt\\s+lam", "tốt lắm"),
            ("tot\\s+lam", "tốt lắm"),
            ("đúng\\s+ra", "đúng ra"),
            ("dung\\s+ra", "đúng ra"),
            ("theo\\s+như\\s+anh\\b", "theo như ảnh"),
            ("như\\s+anh\\s+thì", "như ảnh thì"),
            ("nhu\\s+anh\\s+thi", "như ảnh thì"),
            ("cấu\\s+hinh", "cấu hình"),
            ("cau\\s+hinh", "cấu hình"),
            ("cau\\s+hình", "cấu hình"),
            ("cài\\s+dat", "cài đặt"),
            ("cai\\s+dat", "cài đặt"),
            ("cai\\s+đặt", "cài đặt"),
            ("ứng\\s+dung", "ứng dụng"),
            ("ung\\s+dung", "ứng dụng"),
            ("ung\\s+dụng", "ứng dụng"),
            ("hệ\\s+thong", "hệ thống"),
            ("he\\s+thong", "hệ thống"),
            ("he\\s+thống", "hệ thống"),
            ("chức\\s+nang", "chức năng"),
            ("chuc\\s+nang", "chức năng"),
            ("chuc\\s+năng", "chức năng"),
            ("giao\\s+dien", "giao diện"),
            ("kiểm\\s+tra", "kiểm tra"),
            ("kiem\\s+tra", "kiểm tra"),
            ("sửa\\s+loi", "sửa lỗi"),
            ("sua\\s+loi", "sửa lỗi"),
            ("hỗ\\s+tro", "hỗ trợ"),
            ("ho\\s+tro", "hỗ trợ"),
            ("người\\s+dung", "người dùng"),
            ("nguoi\\s+dung", "người dùng"),
            ("phần\\s+mem", "phần mềm"),
            ("phan\\s+mem", "phần mềm"),
            ("bàn\\s+phim", "bàn phím"),
            ("ban\\s+phim", "bàn phím"),
            ("phím\\s+tat", "phím tắt"),
            ("phim\\s+tat", "phím tắt"),
            ("su\\s+dung", "sử dụng"),
            ("sử\\s+dung", "sử dụng"),
            ("su\\s+dụng", "sử dụng"),
            ("binh\\s+thuong", "bình thường"),
            ("không\\s+can\\s+thiet", "không cần thiết"),
            ("khong\\s+can\\s+thiet", "không cần thiết"),
            ("can\\s+thiet", "cần thiết"),
            ("cần\\s+thiet", "cần thiết"),
            ("can\\s+thiết", "cần thiết"),
            ("không\\s+can\\b", "không cần"),
            ("khong\\s+can\\b", "không cần"),
            ("phải\\s+nhu\\s+the", "phải như thế"),
            ("phai\\s+nhu\\s+the", "phải như thế"),
            ("nhu\\s+the\\b", "như thế"),
            ("như\\s+the\\b", "như thế"),
            ("nhu\\s+thế\\b", "như thế"),
            ("phải\\s+nhu\\b", "phải như"),
            ("phai\\s+nhu\\b", "phải như"),
            ("the\\s+nao\\b", "thế nào"),
            ("thế\\s+nao\\b", "thế nào"),
            ("tinh\\s+ra\\b", "tính ra"),
            ("tính\\s+ra\\s+no\\b", "tính ra nó"),
            ("tinh\\s+ra\\s+no\\b", "tính ra nó"),
            ("bị\\s+loi\\b", "bị lỗi"),
            ("bi\\s+loi\\b", "bị lỗi"),
            ("bi\\s+lỗi\\b", "bị lỗi"),
            ("không\\s+bi\\b", "không bị"),
            ("khong\\s+bi\\b", "không bị"),
            ("đang\\s+bi\\b", "đang bị"),
            ("dang\\s+bi\\b", "đang bị"),
            ("vẫn\\s+bi\\b", "vẫn bị"),
            ("van\\s+bi\\b", "vẫn bị"),
            ("van\\s+bị\\b", "vẫn bị"),
            ("lại\\s+bi\\b", "lại bị"),
            ("lai\\s+bi\\b", "lại bị"),
            ("lai\\s+bị\\b", "lại bị"),
            ("nữa\\s+y\\s+ma\\b", "nữa ý mà"),
            ("nua\\s+y\\s+ma\\b", "nữa ý mà"),
            ("nữa\\s+y\\b", "nữa ý"),
            ("nua\\s+y\\b", "nữa ý"),
            ("y\\s+ma\\b", "ý mà"),
            ("ý\\s+ma\\b", "ý mà"),
            ("nữa\\s+ma\\b", "nữa mà"),
            ("nua\\s+ma\\b", "nữa mà"),
            ("nhưng\\s+ma\\b", "nhưng mà"),
            ("nhung\\s+ma\\b", "nhưng mà"),
            ("thế\\s+ma\\b", "thế mà"),
            ("the\\s+ma\\b", "thế mà"),
            ("vậy\\s+ma\\b", "vậy mà"),
            ("vay\\s+ma\\b", "vậy mà"),
            ("mà\\s+no\\b", "mà nó"),
            ("ma\\s+no\\b", "mà nó"),
            ("ma\\s+nó\\b", "mà nó"),
            ("vì\\s+no\\b", "vì nó"),
            ("vi\\s+no\\b", "vì nó"),
            ("nếu\\s+no\\b", "nếu nó"),
            ("neu\\s+no\\b", "nếu nó"),
            ("thì\\s+no\\b", "thì nó"),
            ("thi\\s+no\\b", "thì nó"),
            ("cho\\s+no\\b", "cho nó"),
            ("của\\s+no\\b", "của nó"),
            ("cua\\s+no\\b", "của nó"),
            ("thấy\\s+no\\b", "thấy nó"),
            ("thay\\s+no\\b", "thấy nó"),
            ("no\\s+đang\\b", "nó đang"),
            ("no\\s+dang\\b", "nó đang"),
            ("no\\s+không\\b", "nó không"),
            ("no\\s+khong\\b", "nó không"),
            ("no\\s+chẳng\\b", "nó chẳng"),
            ("no\\s+chang\\b", "nó chẳng"),
            ("no\\s+bị\\b", "nó bị"),
            ("no\\s+bi\\b", "nó bị"),
            ("no\\s+lại\\b", "nó lại"),
            ("no\\s+lai\\b", "nó lại"),
            ("no\\s+vẫn\\b", "nó vẫn"),
            ("no\\s+van\\b", "nó vẫn"),
            ("no\\s+cũng\\b", "nó cũng"),
            ("no\\s+cung\\b", "nó cũng"),
            ("chang\\s+ra\\s+sao", "chẳng ra sao"),
            ("chẳng\\s+ra\\s+sao", "chẳng ra sao"),
            ("chăng\\s+ra\\s+sao", "chẳng ra sao"),
            ("không\\s+ra\\s+sao", "không ra sao"),
            ("khong\\s+ra\\s+sao", "không ra sao"),
            ("gõ\\s+ca\\b", "gõ cả"),
            ("go\\s+ca\\b", "gõ cả"),
            ("tất\\s+ca\\b", "tất cả"),
            ("tat\\s+ca\\b", "tất cả"),
            ("ca\\s+1\\s+cau\\b", "cả 1 câu"),
            ("cả\\s+1\\s+cau\\b", "cả 1 câu"),
            ("ca\\s+1\\s+câu\\b", "cả 1 câu"),
            ("1\\s+cau\\b", "1 câu"),
            ("một\\s+cau\\b", "một câu"),
            ("mot\\s+cau\\b", "một câu"),
            ("khá\\s+dai\\b", "khá dài"),
            ("kha\\s+dai\\b", "khá dài"),
            ("kha\\s+dài\\b", "khá dài"),
            ("câu\\s+dai\\b", "câu dài"),
            ("cau\\s+dai\\b", "câu dài"),
            ("rất\\s+dai\\b", "rất dài"),
            ("rat\\s+dai\\b", "rất dài"),
            ("quá\\s+dai\\b", "quá dài"),
            ("qua\\s+dai\\b", "quá dài"),
            ("suggest\\s+lai\\b", "suggest lại"),
            ("nhưng\\s+lai\\b", "nhưng lại"),
            ("nhung\\s+lai\\b", "nhưng lại"),
            ("mà\\s+lai\\b", "mà lại"),
            ("ma\\s+lai\\b", "mà lại"),
            ("sao\\s+lai\\b", "sao lại"),
            ("lai\\s+không\\b", "lại không"),
            ("lai\\s+khong\\b", "lại không"),
            ("lại\\s+khong\\b", "lại không"),
            ("không\\s+du\\b", "không đủ"),
            ("khong\\s+du\\b", "không đủ"),
            ("chưa\\s+du\\b", "chưa đủ"),
            ("chua\\s+du\\b", "chưa đủ"),
            ("toàn\\s+bo\\b", "toàn bộ"),
            ("toan\\s+bộ\\b", "toàn bộ"),
            ("toan\\s+bo\\b", "toàn bộ")
        ]
        for (wrong, right) in phraseRepairs {
            joined = joined.replacingOccurrences(of: "(?i)\\b" + wrong + "\\b", with: right, options: .regularExpression)
        }
        return joined
    }

    /// Cleans multiple spaces and fixes punctuation spacing.
    public static func normalizePunctuation(_ text: String) -> String {
        var s = text
        // Replace multiple spaces with single space
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        s = s.trimmingCharacters(in: .whitespaces)

        // Fix space before punctuation e.g. "tốt ." -> "tốt."
        let puncts = [".", ",", "!", "?", ";", ":"]
        for p in puncts {
            s = s.replacingOccurrences(of: " " + p, with: p)
        }

        return s
    }

    // MARK: - Tone Stylers

    private static func applyNaturalTone(_ text: String) -> String {
        let s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        return s
    }

    private static func applyPoliteTone(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }

        // Generic polite transformations
        // 1. Replace casual pronouns
        s = s.replacingOccurrences(of: "(?i)\\bmày\\b", with: "bạn", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)\\btao\\b", with: "tôi", options: .regularExpression)

        // 2. Add respectful polite framing for questions and inquiries
        let lower = s.lowercased()
        let isQuestionOrInquiry = lower.contains("?") ||
            lower.contains("không biết") ||
            lower.contains("thế nào") ||
            lower.contains("sao") ||
            lower.contains("có được không") ||
            lower.contains("được không") ||
            lower.contains("gì") ||
            lower.contains("chưa")

        let hasPolitePrefix = lower.hasPrefix("xin") ||
            lower.hasPrefix("dạ") ||
            lower.hasPrefix("làm ơn") ||
            lower.hasPrefix("vui lòng") ||
            lower.hasPrefix("kính")

        if isQuestionOrInquiry && !hasPolitePrefix {
            if lower.hasPrefix("không biết ") {
                s = "Xin cho tôi hỏi " + s.dropFirst("không biết ".count)
            } else {
                s = "Xin cho tôi hỏi " + s
            }
        }

        // 3. Add respectful polite closing particle 'ạ'
        if !s.hasSuffix("ạ") && !s.hasSuffix("ạ.") && !s.hasSuffix("ạ?") {
            if s.hasSuffix("?") {
                s = String(s.dropLast()).trimmingCharacters(in: .whitespaces) + " ạ?"
            } else if s.hasSuffix(".") {
                s = String(s.dropLast()).trimmingCharacters(in: .whitespaces) + " ạ."
            } else {
                s = s + " ạ"
            }
        }

        // 4. Ensure capitalized start
        if let first = s.first, first.isLowercase {
            s = first.uppercased() + s.dropFirst()
        }

        return s
    }

    private static func applyConciseTone(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }

        // Pruning common wordy phrases, conversational fillers and indirect preambles
        let redundancies: [String: String] = [
            "tôi muốn nói rằng": "",
            "cho tôi hỏi là": "Hỏi:",
            "xin hỏi là": "Hỏi:",
            "xin cho tôi hỏi": "",
            "cho tôi hỏi": "",
            "bạn có thể giúp tôi": "Nhờ bạn",
            "như chúng ta đã biết": "",
            "trong thời điểm hiện tại": "hiện tại",
            "ở thời điểm này": "hiện nay",
            "không biết là": "",
            "không biết": "",
            "tôi nghĩ rằng": "",
            "tôi nghĩ là": ""
        ]

        for (pattern, replacement) in redundancies {
            s = s.replacingOccurrences(of: "(?i)\\b" + pattern + "\\b", with: replacement, options: .regularExpression)
        }

        s = normalizePunctuation(s)

        // Capitalize first letter
        if let first = s.first, first.isLowercase {
            s = first.uppercased() + s.dropFirst()
        }

        return s
    }

    // MARK: - English Shorthand & Tone Stylers

    /// Expands English contractions and shorthand tokens.
    public static func expandEnglishShorthand(_ text: String) -> String {
        let tokens = text.components(separatedBy: " ")
        var expanded: [String] = []

        for token in tokens {
            if token.isEmpty { continue }
            var prefix = ""
            var suffix = ""
            var core = token

            while let first = core.first, first.isPunctuation {
                prefix.append(first)
                core.removeFirst()
            }
            while let last = core.last, last.isPunctuation {
                suffix = String(last) + suffix
                core.removeLast()
            }

            if !core.isEmpty {
                let replaced = TeencodeDictionary.expandEnglish(core)
                expanded.append(prefix + replaced + suffix)
            } else {
                expanded.append(token)
            }
        }

        return expanded.joined(separator: " ")
    }

    private static func applyEnglishNaturalTone(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        if let first = s.first, first.isLowercase {
            s = first.uppercased() + s.dropFirst()
        }
        return s
    }

    private static func applyEnglishPoliteTone(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        if let first = s.first, first.isLowercase {
            s = first.uppercased() + s.dropFirst()
        }
        if !s.lowercased().contains("could you") && !s.lowercased().contains("thank") {
            if s.hasSuffix("?") || s.hasSuffix(".") {
                s = String(s.dropLast())
            }
            s += " — thank you."
        }
        return s
    }

    private static func applyEnglishConciseTone(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }

        let redundancies: [String: String] = [
            "i do not know how to": "Need help to",
            "i don't know how to": "Need help to",
            "can you please": "Please",
            "could you please": "Please",
            "at this point in time": "now",
            "in order to": "to"
        ]
        for (pattern, replacement) in redundancies {
            s = s.replacingOccurrences(of: "(?i)\\b" + pattern + "\\b", with: replacement, options: .regularExpression)
        }
        s = normalizePunctuation(s)
        if let first = s.first, first.isLowercase {
            s = first.uppercased() + s.dropFirst()
        }
        return s
    }
}
