import Foundation

/// Represents a parsed Vietnamese syllable.
public struct VietnameseSyllable: Equatable, Sendable {
    public var rawInput: String
    public var initialConsonant: String
    public var vowels: [Character] // vowels stripped of tones
    public var finalConsonant: String
    public var tone: ToneMark
    public var tonePlacement: TonePlacement

    public init(
        rawInput: String = "",
        initialConsonant: String = "",
        vowels: [Character] = [],
        finalConsonant: String = "",
        tone: ToneMark = .none,
        tonePlacement: TonePlacement = .modern
    ) {
        self.rawInput = rawInput
        self.initialConsonant = initialConsonant
        self.vowels = vowels
        self.finalConsonant = finalConsonant
        self.tone = tone
        self.tonePlacement = tonePlacement
    }

    /// Determines the index of the vowel in `vowels` that receives the tone mark.
    public var toneTargetIndex: Int {
        guard !vowels.isEmpty else { return 0 }
        if vowels.count == 1 {
            return 0
        }

        let vowelStr = String(vowels).lowercased()
        let hasFinal = !finalConsonant.isEmpty

        if vowels.count == 2 {
            // Check special initials: qu-, gi-
            let lowerInitial = initialConsonant.lowercased()
            if lowerInitial == "qu" {
                // For 'qu', the first vowel letter is often after 'u', unless 'u' wasn't part of initial
                // But here vowels are after initialConsonant
            }

            if hasFinal {
                // e.g. "toan" -> "toán", "tieng" -> "tiếng", "duong" -> "đường"
                // Tone goes to the 2nd vowel
                return 1
            } else {
                // Open syllable
                // 1. oa, oe, uy
                if vowelStr == "oa" || vowelStr == "oe" || vowelStr == "uy" {
                    return tonePlacement == .modern ? 0 : 1
                }
                // 2. ia, ua, ưa
                if vowelStr == "ia" || vowelStr == "ua" || vowelStr == "ưa" {
                    return 0
                }
                // 3. Diphthongs with a modified 2nd vowel (iê, yê, uơ, uô, ươ, uâ, oă): tone ALWAYS goes on the 2nd vowel (index 1), even while typing before the final consonant (e.g. "tiees" -> "tiế" -> "tiếp")
                if vowelStr == "iê" || vowelStr == "yê" || vowelStr == "uơ" || vowelStr == "uô" || vowelStr == "ươ" || vowelStr == "uâ" || vowelStr == "oă" {
                    return 1
                }
                // 4. Diphthongs ending in offglides i, y, u, o (ai, ao, au, ay, eo, êu, oi, ôi, ơi, ui, ưi, ây)
                if vowelStr.hasSuffix("i") || vowelStr.hasSuffix("y") ||
                   vowelStr.hasSuffix("u") || vowelStr.hasSuffix("o") {
                    return 0
                }
                return 0
            }
        }

        if vowels.count == 3 {
            let vowelStr = String(vowels).lowercased()
            if vowelStr == "uyê" || vowelStr == "uye" {
                return 2
            }
            // Triphthongs: oai, oay, uôi, ươi, iêu, yêu
            // Tone typically goes to the middle vowel (index 1)
            return 1
        }

        return 0
    }

    /// Reconstructs the formatted Vietnamese string.
    public func formattedString() -> String {
        guard !vowels.isEmpty else {
            return initialConsonant + finalConsonant
        }

        var tonedVowels = vowels
        let targetIdx = toneTargetIndex
        if targetIdx >= 0 && targetIdx < tonedVowels.count && tone != .none {
            tonedVowels[targetIdx] = VietnameseVowelMap.applyTone(tonedVowels[targetIdx], tone: tone)
        }

        return initialConsonant + String(tonedVowels) + finalConsonant
    }
}

public struct SyllableParser {
    private static let compoundInitials = [
        "ngh", "ng", "nh", "ch", "th", "tr", "ph", "gh", "kh", "qu", "gi"
    ]
    private static let singleInitials: Set<Character> = [
        "b", "c", "d", "đ", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x"
    ]
    private static let validFinals: Set<String> = [
        "c", "ch", "m", "n", "ng", "nh", "p", "t"
    ]

    /// Parses a word string into a VietnameseSyllable.
    public static func parse(_ word: String, tonePlacement: TonePlacement = .modern) -> VietnameseSyllable {
        guard !word.isEmpty else {
            return VietnameseSyllable(tonePlacement: tonePlacement)
        }

        let chars = Array(word)
        var detectedTone: ToneMark = .none
        var initial = ""
        var vowels: [Character] = []
        var final = ""

        // Extract any existing tone from the vowels
        for ch in chars {
            let t = VietnameseVowelMap.extractTone(ch)
            if t != .none {
                detectedTone = t
                break
            }
        }

        // Clean characters of tones for parsing
        var strippedChars: [Character] = []
        for ch in chars {
            strippedChars.append(VietnameseVowelMap.stripTone(ch))
        }

        var idx = 0
        let count = strippedChars.count

        // 1. Initial Consonant
        let lowerWord = String(strippedChars).lowercased()
        var initialMatched = false

        for compound in compoundInitials {
            if lowerWord.hasPrefix(compound) {
                // Special check for 'gi': if followed by a vowel (e.g. "gia", "giu", "gio", "giữ"), 'gi' is initial.
                // If NOT followed by a vowel (e.g. "gì", "gìn", "gìm", "gịp"), 'g' is initial and 'i' is the vowel!
                if compound == "gi" {
                    let hasVowelAfterGi = (count > 2) && VietnameseVowelMap.isVowel(strippedChars[2])
                    if !hasVowelAfterGi {
                        initial = String(strippedChars[0])
                        idx = 1
                    } else {
                        initial = String(strippedChars[0..<2])
                        idx = 2
                    }
                } else if compound == "qu" {
                    let hasVowelAfterQu = (count > 2) && VietnameseVowelMap.isVowel(strippedChars[2])
                    if !hasVowelAfterQu {
                        initial = String(strippedChars[0])
                        idx = 1
                    } else {
                        initial = String(strippedChars[0..<2])
                        idx = 2
                    }
                } else {
                    initial = String(strippedChars[0..<compound.count])
                    idx = compound.count
                }
                initialMatched = true
                break
            }
        }

        if !initialMatched && idx < count {
            let firstLower = Character(strippedChars[idx].lowercased())
            if singleInitials.contains(firstLower) {
                initial = String(strippedChars[idx])
                idx += 1
            }
        }

        // 2. Vowels
        while idx < count && VietnameseVowelMap.isVowel(strippedChars[idx]) {
            vowels.append(strippedChars[idx])
            idx += 1
        }

        // 3. Final Consonant
        if idx < count {
            final = String(strippedChars[idx..<count])
        }

        return VietnameseSyllable(
            rawInput: word,
            initialConsonant: initial,
            vowels: vowels,
            finalConsonant: final,
            tone: detectedTone,
            tonePlacement: tonePlacement
        )
    }

    // MARK: - Phonotactic & Orthographic Validation

    /// Open-only multi-vowel clusters that can NEVER be followed by a final consonant in Vietnamese.
    private static let openOnlyVowelClusters: Set<String> = [
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iu",
        "oi", "ôi", "ơi", "ua", "ưa", "ui", "ưi", "ưu",
        "iêu", "yêu", "oai", "oay", "oeo", "uây", "uôi", "ươi", "ươu", "uya", "uyu",
        "ieu", "yeu", "uoi", "ưoi", "uơi"
    ]

    /// Multi-vowel clusters that CAN be followed by a valid Vietnamese final consonant.
    private static let closedCapableVowelClusters: Set<String> = [
        "iê", "yê", "uô", "ươ", "oa", "oă", "uâ", "oe", "uê", "uy", "uyê", "oo",
        "ie", "ye", "uo", "ưo", "uơ", "uye"
    ]

    /// Single Vietnamese vowels.
    private static let singleVowelClusters: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y"
    ]

    /// Initials permitted before the "oe" vowel cluster in Vietnamese.
    private static let validOeInitials: Set<String> = [
        "", "h", "kh", "l", "ng", "nh", "th", "tr", "x", "đ", "t"
    ]

    /// Checked stop finals that require acute (sắc) or dot (nặng) tone in Vietnamese.
    private static let checkedStopFinals: Set<String> = [
        "c", "ch", "p", "t"
    ]

    /// Validates whether `formatted` (produced from `raw`) obeys Vietnamese phonotactic & orthographic laws.
    public static func isValidVietnameseSyllable(
        raw: String,
        formatted: String,
        isWordBoundary: Bool = false
    ) -> Bool {
        guard !formatted.isEmpty else { return true }

        // Single or double 'd' -> 'đ' is always valid while typing
        let lowerFormatted = formatted.lowercased()
        if lowerFormatted == "đ" {
            return true
        }

        let parsed = parse(formatted)
        let lowerInitial = parsed.initialConsonant.lowercased()
        let lowerFinal = parsed.finalConsonant.lowercased()
        let vowelCluster = String(parsed.vowels).lowercased()

        // Law 1: Must contain at least one vowel in the nucleus (if vowels is empty, there was an invalid initial cluster)
        if parsed.vowels.isEmpty {
            return false
        }

        // Law 2: Final consonant must contain ZERO vowels (blocks multi-syllable words like "editor", "server", "support", "vietnamese")
        // and must be one of the 8 valid Vietnamese final consonants (or empty)
        if !lowerFinal.isEmpty && !validFinals.contains(lowerFinal) {
            return false
        }

        // Law 3: Orthographic C / K / GH / NGH complementary distribution rules
        if let firstVowel = vowelCluster.first {
            let frontVowels: Set<Character> = ["e", "ê", "i", "y"]
            if lowerInitial == "c" && frontVowels.contains(firstVowel) {
                // In Vietnamese, 'c' never precedes e, ê, i, y (e.g. blocks "cell", "center", "city", "cyber")
                return false
            }
            if lowerInitial == "k" && !frontVowels.contains(firstVowel) {
                // In Vietnamese, 'k' only precedes e, ê, i, y (e.g. blocks "karma", "kotlin", "kudos")
                return false
            }
            if (lowerInitial == "gh" || lowerInitial == "ngh") && !["e", "ê", "i"].contains(firstVowel) {
                // In Vietnamese, 'gh'/'ngh' only precede e, ê, i (e.g. blocks "ghost", "ghoul")
                return false
            }
        }

        // Law 4: Vowel cluster validity & closed-rime compatibility
        let isSingleVowel = singleVowelClusters.contains(vowelCluster)
        let isOpenOnly = openOnlyVowelClusters.contains(vowelCluster)
        let isClosedCapable = closedCapableVowelClusters.contains(vowelCluster)

        if !isSingleVowel && !isOpenOnly && !isClosedCapable {
            // Rejects invalid vowel clusters like "ea", "ou", "io", "ae", "ue" (without hat), "ya", "yo"
            return false
        }

        // Open-only diphthongs/triphthongs can NEVER have a final consonant (blocks "using"->uing, "music"->uic, "basic"->aic, "point"->oint)
        if isOpenOnly && !lowerFinal.isEmpty {
            return false
        }

        // Open plain "ie" (without hat 'ê' and with no final consonant) cannot take a tone mark (blocks "fire", "wire", "hire", "tire", "rise", "wise", "life", "wife")
        if vowelCluster == "ie" && lowerFinal.isEmpty && parsed.tone != .none {
            return false
        }

        // "oe" is only valid after specific Vietnamese initials (blocks "more", "core", "store", "close", "rose", "pose")
        if vowelCluster == "oe" && !validOeInitials.contains(lowerInitial) {
            return false
        }

        // Law 5: Checked stop finals ("c", "ch", "p", "t") can NEVER take grave (huyền), hook (hỏi), or tilde (ngã) tones!
        // Immediately blocks "part", "port", "sort", "cart", "hurt", "dirt", "left", "soft", "gift", "lift", "next", "text", "arc", "corp"
        if checkedStopFinals.contains(lowerFinal) {
            if parsed.tone == .grave || parsed.tone == .hook || parsed.tone == .tilde {
                return false
            }
            // On word boundary (Space/punctuation), a modified Vietnamese word ending in c, ch, p, t MUST have acute or dot tone
            // (blocks "root"->rôt, "boot"->bôt, "loop"->lôp, "keep"->kêp, "deep"->dêp, "meet"->mêt)
            if isWordBoundary && formatted != raw && parsed.tone == .none {
                return false
            }
        }

        // Law 6: On word boundary, short vowels ("ă", "â") and pre-consonantal diphthongs ("iê", "yê", "uô", "uâ", "oă")
        // can NEVER stand at the end of an open syllable without a final consonant!
        // (blocks "raw"->ră, "saw"->să, "law"->lă, "paw"->pă, "thaw"->thă)
        if isWordBoundary && lowerFinal.isEmpty {
            let nonOpenCompleteVowels: Set<String> = ["ă", "â", "iê", "yê", "uô", "uâ", "oă", "ie", "ye", "uo"]
            if nonOpenCompleteVowels.contains(vowelCluster) {
                return false
            }
        }

        return true
    }
}
