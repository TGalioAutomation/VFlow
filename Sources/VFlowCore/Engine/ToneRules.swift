import Foundation

/// Rules determining how tone marks are placed on diphthongs/triphthongs.
public enum TonePlacement: String, Codable, CaseIterable, Sendable {
    /// Modern style: hòa, hóa, thủy, khỏe
    case modern
    /// Traditional style: hoà, hoá, thuỷ, khoẻ
    case traditional
}

/// Vietnamese tone marks (5 active tones + neutral).
public enum ToneMark: Int, Codable, CaseIterable, Sendable {
    case none = 0
    case acute = 1   // Sắc (/)
    case grave = 2   // Huyền (\)
    case hook = 3    // Hỏi (?)
    case tilde = 4   // Ngã (~)
    case dot = 5     // Nặng (.)
}

/// Vowel accent modifications (hat, breve, horn, bar).
public enum VowelModification: Int, Codable, CaseIterable, Sendable {
    case none = 0
    case hat = 1    // â, ê, ô
    case breve = 2  // ă
    case horn = 3   // ơ, ư
}

public struct VietnameseVowelMap {
    // Array order: [none, acute, grave, hook, tilde, dot]
    private static let plainA: [Character] = ["a", "á", "à", "ả", "ã", "ạ"]
    private static let breveA: [Character] = ["ă", "ắ", "ằ", "ẳ", "ẵ", "ặ"]
    private static let hatA:   [Character] = ["â", "ấ", "ầ", "ẩ", "ẫ", "ậ"]
    private static let plainE: [Character] = ["e", "é", "è", "ẻ", "ẽ", "ẹ"]
    private static let hatE:   [Character] = ["ê", "ế", "ề", "ể", "ễ", "ệ"]
    private static let plainI: [Character] = ["i", "í", "ì", "ỉ", "ĩ", "ị"]
    private static let plainO: [Character] = ["o", "ó", "ò", "ỏ", "õ", "ọ"]
    private static let hatO:   [Character] = ["ô", "ố", "ồ", "ổ", "ỗ", "ộ"]
    private static let hornO:  [Character] = ["ơ", "ớ", "ờ", "ở", "ỡ", "ợ"]
    private static let plainU: [Character] = ["u", "ú", "ù", "ủ", "ũ", "ụ"]
    private static let hornU:  [Character] = ["ư", "ứ", "ừ", "ử", "ữ", "ự"]
    private static let plainY: [Character] = ["y", "ý", "ỳ", "ỷ", "ỹ", "ỵ"]

    // Uppercase
    private static let upperPlainA: [Character] = ["A", "Á", "À", "Ả", "Ã", "Ạ"]
    private static let upperBreveA: [Character] = ["Ă", "Ắ", "Ằ", "Ẳ", "Ẵ", "Ặ"]
    private static let upperHatA:   [Character] = ["Â", "Ấ", "Ầ", "Ẩ", "Ẫ", "Ậ"]
    private static let upperPlainE: [Character] = ["E", "É", "È", "Ẻ", "Ẽ", "Ẹ"]
    private static let upperHatE:   [Character] = ["Ê", "Ế", "Ề", "Ể", "Ễ", "Ệ"]
    private static let upperPlainI: [Character] = ["I", "Í", "Ì", "Ỉ", "Ĩ", "Ị"]
    private static let upperPlainO: [Character] = ["O", "Ó", "Ò", "Ỏ", "Õ", "Ọ"]
    private static let upperHatO:   [Character] = ["Ô", "Ố", "Ồ", "Ổ", "Ỗ", "Ộ"]
    private static let upperHornO:  [Character] = ["Ơ", "Ớ", "Ờ", "Ở", "Ỡ", "Ợ"]
    private static let upperPlainU: [Character] = ["U", "Ú", "Ù", "Ủ", "Ũ", "Ụ"]
    private static let upperHornU:  [Character] = ["Ư", "Ứ", "Ừ", "Ử", "Ữ", "Ự"]
    private static let upperPlainY: [Character] = ["Y", "Ý", "Ỳ", "Ỷ", "Ỹ", "Ỵ"]

    private static let allVowelFamilies: [[Character]] = [
        plainA, breveA, hatA,
        plainE, hatE,
        plainI,
        plainO, hatO, hornO,
        plainU, hornU,
        plainY,
        upperPlainA, upperBreveA, upperHatA,
        upperPlainE, upperHatE,
        upperPlainI,
        upperPlainO, upperHatO, upperHornO,
        upperPlainU, upperHornU,
        upperPlainY
    ]

    /// Returns whether the character is any Vietnamese vowel (with or without tone/accent).
    public static func isVowel(_ ch: Character) -> Bool {
        for family in allVowelFamilies {
            if family.contains(ch) { return true }
        }
        return false
    }

    /// Extracts the tone mark from a character. Returns `.none` if untoned or not a vowel.
    public static func extractTone(_ ch: Character) -> ToneMark {
        for family in allVowelFamilies {
            if let idx = family.firstIndex(of: ch) {
                return ToneMark(rawValue: idx) ?? .none
            }
        }
        return .none
    }

    /// Strips the tone mark, keeping any vowel accent (ă, â, ê, ô, ơ, ư).
    public static func stripTone(_ ch: Character) -> Character {
        for family in allVowelFamilies {
            if family.contains(ch) {
                return family[0]
            }
        }
        return ch
    }

    /// Applies a tone mark to a vowel character.
    public static func applyTone(_ ch: Character, tone: ToneMark) -> Character {
        for family in allVowelFamilies {
            if family.contains(ch) {
                let toneIndex = min(tone.rawValue, family.count - 1)
                return family[toneIndex]
            }
        }
        return ch
    }

    /// Returns base ASCII vowel without any accent or tone (e.g. ắ -> a, Ệ -> E).
    public static func toBaseAscii(_ ch: Character) -> Character {
        let isUpper = ch.isUppercase
        let lower = Character(ch.lowercased())
        let stripped = stripTone(lower)
        let baseLower: Character
        switch stripped {
        case "a", "ă", "â": baseLower = "a"
        case "e", "ê":      baseLower = "e"
        case "i":           baseLower = "i"
        case "o", "ô", "ơ": baseLower = "o"
        case "u", "ư":      baseLower = "u"
        case "y":           baseLower = "y"
        case "đ":           baseLower = "d"
        default:            baseLower = lower
        }
        return isUpper ? Character(baseLower.uppercased()) : baseLower
    }

    /// Applies vowel modification (hat, breve, horn) to a base character.
    public static func applyModification(_ ch: Character, mod: VowelModification) -> Character {
        let base = toBaseAscii(ch)
        let isUpper = ch.isUppercase
        let lower = Character(base.lowercased())
        var resultLower: Character = lower

        switch (lower, mod) {
        case ("a", .hat):   resultLower = "â"
        case ("a", .breve): resultLower = "ă"
        case ("e", .hat):   resultLower = "ê"
        case ("o", .hat):   resultLower = "ô"
        case ("o", .horn):  resultLower = "ơ"
        case ("u", .horn):  resultLower = "ư"
        default: break
        }

        return isUpper ? Character(resultLower.uppercased()) : resultLower
    }
}
