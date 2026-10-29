import Foundation

/// Fast mapping of Vietnamese abbreviations, acronyms, and teencode.
public struct TeencodeDictionary: Sendable {
    public static let mapping: [String: String] = [
        "ko": "không",
        "k": "không",
        "hong": "không",
        "hông": "không",
        "khum": "không",
        "đc": "được",
        "dc": "được",
        "j": "gì",
        "ntn": "như thế nào",
        "mn": "mọi người",
        "cx": "cũng",
        "vs": "với",
        "thg": "thường",
        "thg`": "thường",
        "kb": "không biết",
        "trc": "trước",
        "bh": "bây giờ",
        "hnay": "hôm nay",
        "ng": "người",
        "mik": "mình",
        "mk": "mình",
        "m": "mình",
        "b": "bạn",
        "ns": "nói",
        "tl": "trả lời",
        "ib": "nhắn tin",
        "rep": "phản hồi",
        "r": "rồi",
        "roi": "rồi",
        "wa": "quá",
        "lun": "luôn",
        "h": "giờ",
        "ad": "quản trị viên",
        "ak": "ạ",
        "ah": "ạ",
        "nha": "nhé",
        "nhe": "nhé",
        "mún": "muốn",
        "bik": "biết",
        "hok": "không",
        "z": "vậy",
        "zậy": "vậy",
        "tn": "thế này",
        "tks": "cảm ơn"
    ]

    /// English shorthand, contraction, and high-frequency typo dictionary for English / Bilingual text polishing.
    public static let englishMapping: [String: String] = [
        "dont": "don't",
        "dontt": "don't",
        "donnt": "don't",
        "doont": "don't",
        "cant": "can't",
        "cantt": "can't",
        "cannt": "can't",
        "caant": "can't",
        "cann": "can",
        "cannn": "can",
        "cannnn": "can",
        "wont": "won't",
        "wontt": "won't",
        "wonnt": "won't",
        "didnt": "didn't",
        "didntt": "didn't",
        "doesnt": "doesn't",
        "doesntt": "doesn't",
        "isnt": "isn't",
        "isntt": "isn't",
        "arent": "aren't",
        "arentt": "aren't",
        "wasnt": "wasn't",
        "wasntt": "wasn't",
        "werent": "weren't",
        "werentt": "weren't",
        "havent": "haven't",
        "haventt": "haven't",
        "hasnt": "hasn't",
        "hasntt": "hasn't",
        "hadnt": "hadn't",
        "hadntt": "hadn't",
        "wouldnt": "wouldn't",
        "wouldntt": "wouldn't",
        "woudnt": "wouldn't",
        "couldnt": "couldn't",
        "couldntt": "couldn't",
        "coudnt": "couldn't",
        "shouldnt": "shouldn't",
        "shouldntt": "shouldn't",
        "shoudnt": "shouldn't",
        "woud": "would",
        "coud": "could",
        "shoud": "should",
        "im": "I'm",
        "imm": "I'm",
        "immm": "I'm",
        "ive": "I've",
        "id": "I'd",
        "ill": "I'll",
        "youre": "you're",
        "theyre": "they're",
        "thats": "that's",
        "whats": "what's",
        "theres": "there's",
        "heres": "here's",
        "pls": "please",
        "plss": "please",
        "plsss": "please",
        "plz": "please",
        "thx": "thanks",
        "thxx": "thanks",
        "thxxx": "thanks",
        "tysm": "thank you so much",
        "btw": "by the way",
        "imo": "in my opinion",
        "imho": "in my humble opinion",
        "tbh": "to be honest",
        "asap": "as soon as possible",
        "fyi": "for your information",
        "w/": "with",
        "w/o": "without",
        "bc": "because",
        "cuz": "because",
        "becuase": "because",
        "beacuse": "because",
        "teh": "the",
        "thhe": "the",
        "recieve": "receive",
        "seperate": "separate",
        "definately": "definitely",
        "occured": "occurred",
        "untill": "until",
        "wich": "which",
        "thier": "their",
        "togehter": "together",
        "wierd": "weird",
        "freind": "friend",
        "beleive": "believe",
        "achive": "achieve",
        "enviroment": "environment",
        "goverment": "government",
        "neccessary": "necessary",
        "succesful": "successful",
        "tommorow": "tomorrow",
        "tomorow": "tomorrow",
        "u": "you",
        "ur": "your"
    ]

    /// Genuine English words that naturally contain a double vowel or double final consonant (`ll`, `ss`, `ff`, `ee`, `oo`, `dd`, `gg`).
    private static let validDoubleLetterEnglishWords: Set<String> = [
        "all", "ball", "call", "fall", "hall", "mall", "small", "stall", "tall", "wall",
        "bell", "cell", "fell", "hell", "sell", "shell", "smell", "spell", "swell", "tell", "well", "yell",
        "bill", "chill", "drill", "fill", "grill", "hill", "kill", "mill", "pill", "skill", "spill", "still", "will",
        "bull", "dull", "full", "null", "pull", "doll", "poll", "roll", "toll",
        "pass", "mass", "class", "glass", "grass", "less", "mess", "press", "dress", "stress", "guess", "bless",
        "success", "access", "process", "miss", "kiss", "loss", "boss", "cross", "across", "issue", "session", "message",
        "off", "staff", "stuff", "stiff", "cliff", "diff", "buff", "office", "offer", "coffee",
        "see", "seen", "seed", "seek", "seem", "need", "feed", "feel", "free", "tree", "three", "agree", "degree",
        "keep", "deep", "sleep", "week", "meet", "feet", "sweet", "street", "sheet", "green", "screen", "queen", "between",
        "too", "good", "food", "mood", "wood", "book", "look", "took", "cook", "hook", "cool", "tool", "pool", "school",
        "fool", "soon", "moon", "noon", "room", "zoom", "boom", "root", "boot", "shoot", "foot", "door", "floor", "poor",
        "choose", "loose", "add", "odd", "egg", "err"
    ]

    /// Collapses character runs of length `>= minRun` down to `targetRun` characters.
    private static func collapseRepeatedRuns(_ word: String, minRun: Int, targetRun: Int) -> String {
        let chars = Array(word)
        guard chars.count >= minRun else { return word }
        var result: [Character] = []
        var i = 0
        while i < chars.count {
            let current = chars[i]
            var runLen = 1
            while i + runLen < chars.count && chars[i + runLen] == current {
                runLen += 1
            }
            let keepCount = runLen >= minRun ? targetRun : runLen
            for _ in 0..<keepCount {
                result.append(current)
            }
            i += runLen
        }
        return String(result)
    }

    /// Normalizes repeated-letter English typos (e.g. "cannn" -> "can", "dooo" -> "do", "ittt" -> "it",
    /// "willl" -> "will", "gooddd" -> "good", "neeed" -> "need", "helppp" -> "help", "workkk" -> "work", "dontt" -> "don't").
    public static func normalizeEnglishRepeatedLetters(_ word: String) -> String? {
        let lower = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lower.count >= 2 else { return nil }
        guard lower.unicodeScalars.allSatisfy({ $0.value <= 127 }) else { return nil }

        // 1. Direct dictionary hit
        if let direct = englishMapping[lower] {
            return direct
        }

        // If already a known valid English word, do not alter it
        if validDoubleLetterEnglishWords.contains(lower) ||
           SmartEnglishDetector.commonEnglishWords.contains(lower) ||
           VietnameseTextPolisher.enGrammarAndCommonWords.contains(lower) ||
           SmartEnglishDetector.contextualEnglishHomographs.contains(lower) {
            return nil
        }

        // 2. Try collapsing 3+ identical consecutive letters down to 2 (e.g. "willl" -> "will", "neeed" -> "need", "alll" -> "all")
        let collapsed3To2 = collapseRepeatedRuns(lower, minRun: 3, targetRun: 2)
        if collapsed3To2 != lower {
            if let mapped = englishMapping[collapsed3To2] {
                return mapped
            }
            if validDoubleLetterEnglishWords.contains(collapsed3To2) ||
               SmartEnglishDetector.commonEnglishWords.contains(collapsed3To2) {
                return collapsed3To2
            }
        }

        // 3. Try collapsing 3+ identical consecutive letters down to 1 (e.g. "cannn" -> "can", "dooo" -> "do", "ittt" -> "it", "gooddd" -> "good")
        let collapsed3To1 = collapseRepeatedRuns(lower, minRun: 3, targetRun: 1)
        if collapsed3To1 != lower {
            if let mapped = englishMapping[collapsed3To1] {
                return mapped
            }
            if VietnameseTextPolisher.enGrammarAndCommonWords.contains(collapsed3To1) ||
               SmartEnglishDetector.commonEnglishWords.contains(collapsed3To1) ||
               SmartEnglishDetector.contextualEnglishHomographs.contains(collapsed3To1) {
                return collapsed3To1
            }
        }

        // 4. Try collapsing trailing duplicate consonant/letter where English does not double that ending
        // (e.g. "cann" -> "can", "workk" -> "work", "helpp" -> "help", "fixx" -> "fix", "itt" -> "it", "dontt" -> "don't")
        let chars = Array(lower)
        if chars.count >= 3,
           let last = chars.last,
           chars[chars.count - 2] == last,
           !["l", "s", "f", "z"].contains(last) {
            let droppedLast = String(chars.dropLast())
            if let mapped = englishMapping[droppedLast] {
                return mapped
            }
            if VietnameseTextPolisher.enGrammarAndCommonWords.contains(droppedLast) ||
               SmartEnglishDetector.commonEnglishWords.contains(droppedLast) ||
               SmartEnglishDetector.contextualEnglishHomographs.contains(droppedLast) {
                return droppedLast
            }
        }

        return nil
    }

    /// Expands a single English shorthand or repeated-letter typo token if found.
    public static func expandEnglish(_ word: String) -> String {
        let lower = word.lowercased()
        if lower == "i" { return "I" }
        guard let expanded = englishMapping[lower] ?? normalizeEnglishRepeatedLetters(lower) else {
            return word
        }
        if let first = word.first, first.isUppercase, !expanded.hasPrefix("I") {
            return expanded.prefix(1).uppercased() + expanded.dropFirst()
        }
        return expanded
    }

    /// Expands a single word if found in the dictionary, preserving capitalization.
    public static func expand(_ word: String) -> String {
        let lower = word.lowercased()
        guard let expanded = mapping[lower] else { return word }

        if word == word.uppercased() && word.count > 1 {
            return expanded.uppercased()
        }
        if let first = word.first, first.isUppercase {
            return expanded.prefix(1).uppercased() + expanded.dropFirst()
        }
        return expanded
    }
}
