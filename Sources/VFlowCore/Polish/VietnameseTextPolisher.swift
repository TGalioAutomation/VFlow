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

        // If any token contains Vietnamese diacritics or known Vietnamese teencode/unsigned words, treat as Vietnamese/Bilingual
        let vnMarkers: Set<String> = [
            "ko", "đc", "dc", "ntn", "mn", "cx", "vs", "kb", "trc", "bh", "hnay", "mik", "mk",
            "toi", "tooi", "dang", "ddang", "khong", "khoong", "khoog", "duoc", "dduoc", "ddwuocj", "dduwocj",
            "chua", "nhung", "nguoi", "truoc", "phai", "biet", "muon", "cung", "nhieu", "luon", "moi",
            "tieng", "viet", "viec", "hoat", "thuc", "that", "thaat", "tot", "nua", "chang", "hien", "thi",
            "cua", "voi", "cho", "lam", "xem", "nghi", "thay", "chuan", "nghia", "phan", "giao", "dien",
            "kiem", "sua", "loi", "nganh", "nghanh", "phap"
        ]
        for tok in tokens {
            if vnMarkers.contains(tok) { return false }
            for ch in tok {
                if ch.unicodeScalars.contains(where: { $0.value > 127 }) {
                    return false
                }
            }
        }

        let enGrammarAndCommonWords: Set<String> = [
            "i", "im", "ive", "ill", "id", "you", "your", "youre", "he", "hes", "him", "his", "she", "shes", "her",
            "it", "its", "we", "were", "us", "our", "they", "theyre", "them", "their", "there", "this", "that", "these", "those",
            "the", "a", "an", "to", "of", "in", "on", "at", "by", "for", "with", "from", "into", "about", "after", "before",
            "between", "without", "through", "during", "until", "against", "among", "within", "because", "although", "though",
            "since", "unless", "while", "when", "where", "what", "which", "who", "whom", "whose", "why", "how", "whether",
            "am", "is", "are", "was", "been", "being", "be", "have", "has", "had", "having", "do", "does", "did", "done", "doing",
            "dont", "doesnt", "didnt", "cant", "cannot", "wont", "wouldnt", "shouldnt", "couldnt", "isnt", "arent", "wasnt",
            "werent", "havent", "hasnt", "hadnt", "will", "would", "shall", "should", "can", "could", "may", "might", "must",
            "go", "goes", "went", "gone", "going", "work", "works", "worked", "working", "make", "makes", "made", "making",
            "take", "takes", "took", "taken", "see", "sees", "saw", "seen", "know", "knows", "knew", "known", "think", "thinks",
            "thought", "want", "wants", "wanted", "need", "needs", "needed", "use", "uses", "used", "using", "try", "tries",
            "tried", "trying", "check", "checks", "checked", "checking", "test", "tests", "tested", "testing", "write", "writes",
            "wrote", "written", "buy", "buys", "bought", "eat", "eats", "ate", "eaten", "come", "comes", "came", "send", "sends",
            "sent", "give", "gives", "gave", "given", "find", "finds", "found", "tell", "tells", "told", "ask", "asks", "asked",
            "seem", "seems", "look", "looks", "looked", "looking", "forward", "hear", "hearing", "discuss", "discussed",
            "explain", "listen", "depend", "depends", "interested", "time", "ready", "home", "school", "yesterday", "today",
            "tomorrow", "week", "month", "year", "night", "morning", "ago", "please", "help", "helps", "fix", "bug", "error",
            "issue", "problem", "answer", "question", "apple", "idea", "hour", "option", "update", "example", "grammar",
            "english", "vietnamese", "sentence", "word", "words", "good", "better", "best", "bad", "worse", "worst", "more",
            "most", "many", "much", "some", "any", "every", "all", "very", "new", "old", "fast", "faster", "easy", "easier",
            "information", "informations", "advice", "advices", "equipment", "equipments", "knowledge", "knowledges", "feedback", "feedbacks"
        ]

        let enMatches = tokens.filter {
            SmartEnglishDetector.commonEnglishWords.contains($0) ||
            SmartEnglishDetector.contextualEnglishHomographs.contains($0) ||
            TeencodeDictionary.englishMapping[$0] != nil ||
            enGrammarAndCommonWords.contains($0)
        }.count

        return enMatches * 2 >= tokens.count
    }

    /// Polishes raw text according to the selected tone (supporting multi-paragraph `\n`, multi-sentence `.`, and Bilingual Vietnamese + English spelling & grammar).
    public static func polish(_ text: String, tone: PolishTone = .natural) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.contains("\n") {
            let lines = trimmed.components(separatedBy: "\n")
            let polishedLines = lines.map { line -> String in
                let cleanLine = line.trimmingCharacters(in: .whitespaces)
                guard !cleanLine.isEmpty else { return "" }
                var p = polishSingleParagraph(cleanLine, tone: tone)
                if let first = p.first, first.isLowercase {
                    p = first.uppercased() + p.dropFirst()
                }
                return p
            }
            return polishedLines.joined(separator: "\n")
        }

        return polishSingleParagraph(trimmed, tone: tone)
    }

    private static func polishSingleParagraph(_ paragraph: String, tone: PolishTone) -> String {
        // Normalize spaces before punctuation first so "pháp . cho" becomes "pháp. cho"
        let preNormalized = normalizePunctuation(paragraph)

        // If the paragraph contains multiple sentences separated by ". ", "! ", or "? ",
        // polish each sentence segment individually so mixed VI/EN sentences and post-period capitalization work seamlessly.
        let sentenceSplits = splitSentencesPreservingDelimiters(preNormalized)
        if sentenceSplits.count > 1 {
            var rebuilt: [String] = []
            for part in sentenceSplits {
                var polishedPart = polishSingleClause(part.sentence, tone: tone)
                if let first = polishedPart.first, first.isLowercase {
                    polishedPart = first.uppercased() + polishedPart.dropFirst()
                }
                if !part.delimiter.isEmpty && !polishedPart.hasSuffix(part.delimiter) {
                    if polishedPart.hasSuffix(".") || polishedPart.hasSuffix("!") || polishedPart.hasSuffix("?") {
                        polishedPart.removeLast()
                    }
                    polishedPart += part.delimiter
                }
                rebuilt.append(polishedPart)
            }
            return normalizePunctuation(rebuilt.joined(separator: " "))
        }

        return polishSingleClause(preNormalized, tone: tone)
    }

    private static func splitSentencesPreservingDelimiters(_ text: String) -> [(sentence: String, delimiter: String)] {
        let ns = text as NSString
        let len = ns.length
        guard len > 0 else { return [] }

        var results: [(String, String)] = []
        var currentStart = 0
        var idx = 0

        while idx < len {
            let ch = ns.character(at: idx)
            if ch == 0x2E || ch == 0x21 || ch == 0x3F { // . ! ?
                // Do not split on decimal numbers like 1.0 or 3.14
                let isDecimal: Bool = {
                    if ch == 0x2E && idx > 0 && idx + 1 < len {
                        let prev = ns.character(at: idx - 1)
                        let next = ns.character(at: idx + 1)
                        if (prev >= 0x30 && prev <= 0x39) && (next >= 0x30 && next <= 0x39) {
                            return true
                        }
                    }
                    return false
                }()
                if !isDecimal {
                    let segRange = NSRange(location: currentStart, length: idx - currentStart)
                    let seg = ns.substring(with: segRange).trimmingCharacters(in: .whitespaces)
                    let delim = ns.substring(with: NSRange(location: idx, length: 1))
                    if !seg.isEmpty {
                        results.append((seg, delim))
                    }
                    idx += 1
                    while idx < len && ns.character(at: idx) == 0x20 {
                        idx += 1
                    }
                    currentStart = idx
                    continue
                }
            }
            idx += 1
        }

        if currentStart < len {
            let tail = ns.substring(from: currentStart).trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty {
                results.append((tail, ""))
            }
        }
        return results
    }

    private static func polishSingleClause(_ clause: String, tone: PolishTone) -> String {
        let trimmed = clause.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let isEnglish = isPrimarilyEnglish(trimmed)

        // Step 1: Remove filler phrases
        var cleaned = removeFillers(trimmed)

        // Step 2: Expand teencode / English shorthand and repair grammar
        if isEnglish {
            cleaned = expandEnglishShorthand(cleaned)
            cleaned = repairEnglishGrammar(cleaned)
        } else {
            cleaned = expandTeencode(cleaned)
            cleaned = repairVietnameseGrammar(cleaned)
        }

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
            ("toan\\s+bo\\b", "toàn bộ"),
            ("cũng\\s+can\\b", "cũng cần"),
            ("cung\\s+can\\b", "cũng cần"),
            ("cần\\s+duoc\\b", "cần được"),
            ("can\\s+duoc\\b", "cần được"),
            ("được\\s+sua\\b", "được sửa"),
            ("duoc\\s+sua\\b", "được sửa"),
            ("sửa\\s+chinh\\s+ta\\b", "sửa chính tả"),
            ("sua\\s+chinh\\s+ta\\b", "sửa chính tả"),
            ("kiểm\\s+tra\\s+ca\\b", "kiểm tra cả"),
            ("kiem\\s+tra\\s+ca\\b", "kiểm tra cả"),
            ("cho\\s+english\\b", "cho English"),
            ("tiếng\\s+english\\b", "tiếng Anh"),
            ("và\\s+tiếng\\s+việt\\b", "và tiếng Việt"),
            ("va\\s+tieng\\s+viet\\b", "và tiếng Việt")
        ]
        for (wrong, right) in phraseRepairs {
            joined = joined.replacingOccurrences(of: "(?i)\\b" + wrong + "\\b", with: right, options: .regularExpression)
        }
        return joined
    }

    /// Repairs Vietnamese orthographic grammar rules (`ng/ngh`, `g/gh`, `c/k`, `d/gi`, `s/x`, `hỏi/ngã`),
    /// confused word pairs (`dành` vs `giành`, `xử lý` vs `sử lý`), and accidental word duplications.
    public static func repairVietnameseGrammar(_ text: String) -> String {
        var s = text

        // 1. Remove accidental consecutive duplicate function words (while preserving valid Vietnamese reduplications like "luôn luôn", "từ từ", "đều đều")
        let duplicateFunctionWordsPattern = "(?i)\\b(là|của|và|hoặc|nhưng|vì|nên|nếu|thì|mà|rằng|bởi|với|trong|ngoài|trên|dưới|đang|đã|sẽ|bị|được|không|chưa|chẳng|hãy|đừng|chớ)\\s+\\1\\b"
        s = s.replacingOccurrences(of: duplicateFunctionWordsPattern, with: "$1", options: .regularExpression)

        // 2. Vietnamese orthographic grammar rules (ng/ngh, g/gh, s/x, d/gi, hỏi/ngã, -t/-c) & semantic collocations
        let vnGrammarRules: [(String, String)] = [
            // ng vs ngh grammar rule (ngh only before i, e, ê; ng before a, ă, â, o, ô, ơ, u, ư)
            ("nghành", "ngành"),
            ("nghẫm", "ngẫm"),
            ("nghượng", "ngượng"),
            ("nghủ", "ngủ"),
            ("nghồi", "ngồi"),
            ("nghố", "ngố"),
            ("nghạc\\s+nhiên", "ngạc nhiên"),
            ("nghiêng\\s+nghả", "nghiêng ngả"),
            ("nghoảnh", "ngoảnh"),
            ("nghoan", "ngoan"),
            ("suy\\s+ngĩ", "suy nghĩ"),
            ("suy\\s+nghỉ", "suy nghĩ"),
            ("ngỉ\\s+ngơi", "nghỉ ngơi"),
            ("nghĩ\\s+ngơi", "nghỉ ngơi"),
            ("nghĩ\\s+dưỡng", "nghỉ dưỡng"),
            ("đề\\s+ngị", "đề nghị"),
            ("công\\s+ngệ", "công nghệ"),
            ("ngề\\s+nghiệp", "nghề nghiệp"),
            ("ngành\\s+ngề", "ngành nghề"),
            ("ngi\\s+ngờ", "nghi ngờ"),
            ("ngiêm\\s+túc", "nghiêm túc"),
            ("ngiên\\s+cứu", "nghiên cứu"),
            ("ý\\s+ngĩa", "ý nghĩa"),
            // g vs gh grammar rule (gh only before i, e, ê; g before a, ă, â, o, ô, ơ, u, ư)
            ("ghặp", "gặp"),
            ("ghửi", "gửi"),
            ("ghọi", "gọi"),
            ("ghần", "gần"),
            ("ghắn", "gắn"),
            ("ghồm", "gồm"),
            ("lắp\\s+gép", "lắp ghép"),
            ("gép\\s+nối", "ghép nối"),
            ("bàn\\s+gế", "bàn ghế"),
            ("gế\\s+ngồi", "ghế ngồi"),
            ("gi\\s+chú", "ghi chú"),
            ("gi\\s+nhớ", "ghi nhớ"),
            ("gi\\s+nhận", "ghi nhận"),
            // Semantic & grammatical homophones (dành vs giành, xử vs sử, -t vs -c, hỏi vs ngã)
            ("giành\\s+thời\\s+gian", "dành thời gian"),
            ("giành\\s+cho\\b", "dành cho"),
            ("để\\s+giành\\b", "để dành"),
            ("dành\\s+chiến\\s+thắng", "giành chiến thắng"),
            ("dành\\s+độc\\s+lập", "giành độc lập"),
            ("dành\\s+giải\\b", "giành giải"),
            ("dành\\s+quyền\\b", "giành quyền"),
            ("sử\\s+lý\\b", "xử lý"),
            ("xữ\\s+lý\\b", "xử lý"),
            ("sữ\\s+lý\\b", "xử lý"),
            ("xử\\s+dụng\\b", "sử dụng"),
            ("sữ\\s+dụng\\b", "sử dụng"),
            ("cập\\s+nhập\\b", "cập nhật"),
            ("sáng\\s+xủa\\b", "sáng sủa"),
            ("xác\\s+xuất\\b", "xác suất"),
            ("sác\\s+xuất\\b", "xác suất"),
            ("sác\\s+suất\\b", "xác suất"),
            ("sản\\s+suất\\b", "sản xuất"),
            ("xản\\s+xuất\\b", "sản xuất"),
            ("bổ\\s+xung\\b", "bổ sung"),
            ("tham\\s+da\\b", "tham gia"),
            ("chia\\s+sẽ\\b", "chia sẻ"),
            ("vất\\s+vã\\b", "vất vả"),
            ("sẳn\\s+sàng\\b", "sẵn sàng"),
            ("dể\\s+dàng\\b", "dễ dàng"),
            ("hổ\\s+trợ\\b", "hỗ trợ"),
            ("kiễm\\s+tra\\b", "kiểm tra"),
            ("kỉ\\s+thuật\\b", "kỹ thuật"),
            ("ngử\\s+pháp\\b", "ngữ pháp"),
            ("ngu\\s+phap\\b", "ngữ pháp"),
            ("ngữ\\s+phap\\b", "ngữ pháp"),
            ("ngu\\s+pháp\\b", "ngữ pháp"),
            ("chính\\s+tã\\b", "chính tả"),
            ("chinh\\s+ta\\b", "chính tả"),
            ("chính\\s+ta\\b", "chính tả"),
            ("trãi\\s+nghiệm\\b", "trải nghiệm"),
            ("chửa\\s+trị\\b", "chữa trị"),
            ("sữa\\s+chữa\\b", "sửa chữa"),
            ("lảng\\s+phí\\b", "lãng phí"),
            ("mải\\s+mãi\\b", "mãi mãi"),
            // Redundant conjunctions
            ("tuy\\s+nhiên\\s+nhưng\\b", "tuy nhiên")
        ]

        for (wrong, right) in vnGrammarRules {
            s = s.replacingOccurrences(of: "(?i)\\b" + wrong, with: right, options: .regularExpression)
        }
        return s
    }

    /// Repairs English grammar: subject-verb agreement, past-time adverbial tense agreement,
    /// article `a` vs `an`, auxiliary/modal verb forms, uncountable nouns, prepositions, and duplicate words.
    public static func repairEnglishGrammar(_ text: String) -> String {
        var s = text

        // 1. Remove accidental consecutive duplicate English words ("the the", "is is", "to to")
        s = s.replacingOccurrences(
            of: "(?i)\\b(the|a|an|is|are|was|were|to|in|on|at|for|of|with|and|or|but|it|this|that)\\s+\\1\\b",
            with: "$1",
            options: .regularExpression
        )

        // 2. Contraction & pronoun normalization
        let contractionRules: [(String, String)] = [
            ("\\bi\\b", "I"),
            ("(?i)\\bim\\b", "I'm"),
            ("(?i)\\bi'm\\b", "I'm"),
            ("(?i)\\bive\\b", "I've"),
            ("(?i)\\bi've\\b", "I've"),
            ("(?i)\\bi'll\\b", "I'll"),
            ("(?i)\\bi'd\\b", "I'd"),
            ("(?i)\\bdont\\b", "don't"),
            ("(?i)\\bdoesnt\\b", "doesn't"),
            ("(?i)\\bdidnt\\b", "didn't"),
            ("(?i)\\bcant\\b", "can't"),
            ("(?i)\\bwont\\b", "won't"),
            ("(?i)\\bisnt\\b", "isn't"),
            ("(?i)\\barent\\b", "aren't"),
            ("(?i)\\bwasnt\\b", "wasn't"),
            ("(?i)\\bwerent\\b", "weren't"),
            ("(?i)\\bhavent\\b", "haven't"),
            ("(?i)\\bhasnt\\b", "hasn't"),
            ("(?i)\\bhadnt\\b", "hadn't"),
            ("(?i)\\bwouldnt\\b", "wouldn't"),
            ("(?i)\\bshouldnt\\b", "shouldn't"),
            ("(?i)\\bcouldnt\\b", "couldn't")
        ]
        for (pattern, replacement) in contractionRules {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        // 3. Past-time adverbial tense agreement (when sentence has "yesterday", "last night/week/month/year", or "ago")
        let lowerS = s.lowercased()
        let hasPastTimeMarker = lowerS.range(
            of: "\\b(yesterday|last\\s+(?:night|week|month|year)|ago)\\b",
            options: .regularExpression
        ) != nil
        if hasPastTimeMarker {
            let pastVerbFixes: [(String, String)] = [
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:go|goes)\\b", "$1 went"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:buy|buys)\\b", "$1 bought"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:eat|eats)\\b", "$1 ate"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:see|sees)\\b", "$1 saw"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:make|makes)\\b", "$1 made"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:take|takes)\\b", "$1 took"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:come|comes)\\b", "$1 came"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:write|writes)\\b", "$1 wrote"),
                ("(?i)\\b(I|you|we|they|he|she|it)\\s+(?:send|sends)\\b", "$1 sent"),
                ("(?i)\\b(I|he|she|it)\\s+(?:am|is)\\b", "$1 was"),
                ("(?i)\\b(you|we|they)\\s+(?:are|is)\\b", "$1 were")
            ]
            for (pattern, replacement) in pastVerbFixes {
                s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
            }
        }

        // 4. Article `a` vs `an` agreement
        s = s.replacingOccurrences(
            of: "(?i)\\ba\\s+(?=(?:apple|error|issue|example|update|option|idea|hour|honest|honor|heir|api|app|element|object|array|image|icon|account|email|event|item|office|offer|order|umbrella|uncle|answer|article|attempt|author|engine|engineer|editor|effect|effort|input|output|index|instance|interface|integer|operator|operation|argument|attribute|exception|expression)\\b)",
            with: "an ",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: "(?i)\\ban\\s+(?=(?:user|users|university|unit|uniform|union|unique|universal|url|utility|bug|feature|test|file|new|good|bad|big|small|long|short|system|button|window|page|project|model|server|client|code|class|function|method|variable|string|number|list|map|set|table|row|column|view|screen|car|house|book|day|week|month|year|time|way|person|man|woman|child|friend|school|company|team|problem|question|result|change|place|part|case|group|point|fact)\\b)",
            with: "a ",
            options: .regularExpression
        )

        // 5. Subject-verb agreement, auxiliary/modal verbs, perfect tense, comparatives & prepositions
        let englishGrammarRules: [(String, String)] = [
            // 3rd-person singular (he / she / it)
            ("(?i)\\b(he|she|it)\\s+don't\\b", "$1 doesn't"),
            ("(?i)\\b(he|she|it)\\b([^.!?]*?)\\band\\s+(?:don't|dont)\\b", "$1$2and doesn't"),
            ("(?i)\\b(he|she|it)\\s+do\\s+not\\b", "$1 does not"),
            ("(?i)\\b(he|she|it)\\s+have\\b", "$1 has"),
            ("(?i)\\b(he|she|it)\\s+haven't\\b", "$1 hasn't"),
            ("(?i)\\b(he|she|it)\\s+are\\b", "$1 is"),
            ("(?i)\\b(he|she|it)\\s+go\\b", "$1 goes"),
            ("(?i)\\b(he|she|it)\\s+do\\b", "$1 does"),
            ("(?i)\\b(he|she|it)\\s+work\\b", "$1 works"),
            ("(?i)\\b(he|she|it)\\s+need\\b", "$1 needs"),
            ("(?i)\\b(he|she|it)\\s+want\\b", "$1 wants"),
            ("(?i)\\b(he|she|it)\\s+like\\b", "$1 likes"),
            ("(?i)\\b(he|she|it)\\s+know\\b", "$1 knows"),
            ("(?i)\\b(he|she|it)\\s+think\\b", "$1 thinks"),
            ("(?i)\\b(he|she|it)\\s+make\\b", "$1 makes"),
            ("(?i)\\b(he|she|it)\\s+take\\b", "$1 takes"),
            ("(?i)\\b(he|she|it)\\s+use\\b", "$1 uses"),
            ("(?i)\\b(he|she|it)\\s+look\\b", "$1 looks"),
            ("(?i)\\b(he|she|it)\\s+seem\\b", "$1 seems"),
            ("(?i)\\b(he|she|it)\\s+help\\b", "$1 helps"),
            ("(?i)\\b(he|she|it)\\s+run\\b", "$1 runs"),
            ("(?i)\\b(he|she|it)\\s+say\\b", "$1 says"),
            ("(?i)\\b(he|she|it)\\s+try\\b", "$1 tries"),
            ("(?i)\\b(he|she|it)\\s+check\\b", "$1 checks"),
            // 1st/2nd/plural subjects (I / you / we / they)
            ("\\bI\\s+(?:is|are)\\b", "I am"),
            ("\\bI\\s+has\\b", "I have"),
            ("\\bI\\s+doesn't\\b", "I don't"),
            ("\\bI\\s+does\\s+not\\b", "I do not"),
            ("(?i)\\b(you|we|they)\\s+is\\b", "$1 are"),
            ("(?i)\\b(you|we|they)\\s+was\\b", "$1 were"),
            ("(?i)\\b(you|we|they)\\s+has\\b", "$1 have"),
            ("(?i)\\b(you|we|they)\\s+doesn't\\b", "$1 don't"),
            ("(?i)\\b(you|we|they)\\s+does\\s+not\\b", "$1 do not"),
            ("(?i)\\b(I|you|we|they)\\s+goes\\b", "$1 go"),
            ("(?i)\\b(I|you|we|they)\\s+works\\b", "$1 work"),
            ("(?i)\\b(I|you|we|they)\\s+needs\\b", "$1 need"),
            ("(?i)\\b(I|you|we|they)\\s+wants\\b", "$1 want"),
            ("(?i)\\b(I|you|we|they)\\s+likes\\b", "$1 like"),
            ("(?i)\\b(I|you|we|they)\\s+knows\\b", "$1 know"),
            ("(?i)\\b(I|you|we|they)\\s+thinks\\b", "$1 think"),
            ("(?i)\\b(I|you|we|they)\\s+makes\\b", "$1 make"),
            // Existential & demonstrative agreement
            ("(?i)\\bthere\\s+is\\s+(many|several|few|two|three|four|five|multiple|a\\s+lot\\s+of)\\b", "there are $1"),
            ("(?i)\\bthis\\s+(things|items|files|issues|errors|problems|people|books|days|words|options)\\b", "these $1"),
            ("(?i)\\bthese\\s+(thing|item|file|issue|error|problem|person|book|day|word|option)\\s+is\\b", "this $1 is"),
            // Auxiliary did / does / do + bare infinitive
            ("(?i)\\b(did|didn't|did\\s+not)\\s+went\\b", "$1 go"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+worked\\b", "$1 work"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+saw\\b", "$1 see"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+came\\b", "$1 come"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+made\\b", "$1 make"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+took\\b", "$1 take"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+wrote\\b", "$1 write"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+bought\\b", "$1 buy"),
            ("(?i)\\b(did|didn't|did\\s+not)\\s+had\\b", "$1 have"),
            ("(?i)\\b(does|doesn't|does\\s+not|do|don't|do\\s+not)\\s+works\\b", "$1 work"),
            ("(?i)\\b(does|doesn't|does\\s+not)\\s+goes\\b", "$1 go"),
            ("(?i)\\b(does|doesn't|does\\s+not)\\s+has\\b", "$1 have"),
            ("(?i)\\b(does|doesn't|does\\s+not)\\s+needs\\b", "$1 need"),
            ("(?i)\\b(does|doesn't|does\\s+not)\\s+wants\\b", "$1 want"),
            ("(?i)\\b(does|doesn't|does\\s+not)\\s+knows\\b", "$1 know"),
            // Modals + bare infinitive
            ("(?i)\\b(can|can't|cannot|will|won't|would|wouldn't|should|shouldn't|could|couldn't|must|may|might)\\s+works\\b", "$1 work"),
            ("(?i)\\b(can|can't|cannot|will|won't|would|wouldn't|should|shouldn't|could|couldn't|must|may|might)\\s+goes\\b", "$1 go"),
            ("(?i)\\b(can|can't|cannot|will|won't|would|wouldn't|should|shouldn't|could|couldn't|must|may|might)\\s+helps\\b", "$1 help"),
            ("(?i)\\b(can|can't|cannot|will|won't|would|wouldn't|should|shouldn't|could|couldn't|must|may|might)\\s+went\\b", "$1 go"),
            ("(?i)\\b(could|would|should|must|might)\\s+of\\b", "$1 have"),
            // Perfect tense (have / has / had + past participle)
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+went\\b", "$1 gone"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+did\\b", "$1 done"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+saw\\b", "$1 seen"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+wrote\\b", "$1 written"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+took\\b", "$1 taken"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+ate\\b", "$1 eaten"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+spoke\\b", "$1 spoken"),
            ("(?i)\\b(have|has|had|haven't|hasn't|hadn't|I've)\\s+broke\\b", "$1 broken"),
            // Double comparatives, prepositions & uncountable nouns
            ("(?i)\\bmore\\s+better\\b", "better"),
            ("(?i)\\bmore\\s+faster\\b", "faster"),
            ("(?i)\\bmore\\s+easier\\b", "easier"),
            ("(?i)\\bmore\\s+worse\\b", "worse"),
            ("(?i)\\bmost\\s+best\\b", "best"),
            ("(?i)\\bdiscuss\\s+about\\b", "discuss"),
            ("(?i)\\bdiscussed\\s+about\\b", "discussed"),
            ("(?i)\\bdiscussing\\s+about\\b", "discussing"),
            ("(?i)\\bexplain\\s+me\\b", "explain to me"),
            ("(?i)\\blisten\\s+me\\b", "listen to me"),
            ("(?i)\\breply\\s+me\\b", "reply to me"),
            ("(?i)\\bdepend\\s+of\\b", "depend on"),
            ("(?i)\\bdepends\\s+of\\b", "depends on"),
            ("(?i)\\binterested\\s+on\\b", "interested in"),
            ("(?i)\\bgood\\s+in\\b", "good at"),
            ("(?i)\\blook\\s+forward\\s+to\\s+see\\b", "look forward to seeing"),
            ("(?i)\\blooking\\s+forward\\s+to\\s+see\\b", "looking forward to seeing"),
            ("(?i)\\blook\\s+forward\\s+to\\s+hear\\b", "look forward to hearing"),
            ("(?i)\\blooking\\s+forward\\s+to\\s+hear\\b", "looking forward to hearing"),
            ("(?i)\\binformations\\b", "information"),
            ("(?i)\\badvices\\b", "advice"),
            ("(?i)\\bequipments\\b", "equipment"),
            ("(?i)\\bknowledges\\b", "knowledge"),
            ("(?i)\\bfeedbacks\\b", "feedback"),
            ("(?i)\\bsoftwares\\b", "software"),
            ("(?i)\\bhomeworks\\b", "homework")
        ]

        for (pattern, replacement) in englishGrammarRules {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return s
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
