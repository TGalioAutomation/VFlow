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

    /// English shorthand & contraction dictionary for English / Bilingual text polishing.
    public static let englishMapping: [String: String] = [
        "dont": "don't",
        "cant": "can't",
        "wont": "won't",
        "didnt": "didn't",
        "doesnt": "doesn't",
        "isnt": "isn't",
        "arent": "aren't",
        "wasnt": "wasn't",
        "werent": "weren't",
        "havent": "haven't",
        "hasnt": "hasn't",
        "wouldnt": "wouldn't",
        "couldnt": "couldn't",
        "shouldnt": "shouldn't",
        "im": "I'm",
        "ive": "I've",
        "id": "I'd",
        "ill": "I'll",
        "pls": "please",
        "plz": "please",
        "thx": "thanks",
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
        "u": "you",
        "ur": "your"
    ]

    /// Expands a single English shorthand token if found.
    public static func expandEnglish(_ word: String) -> String {
        let lower = word.lowercased()
        if lower == "i" { return "I" }
        guard let expanded = englishMapping[lower] else { return word }
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
