import Foundation

/// Corrects typing mistakes in Vietnamese words, such as duplicate/conflicting tone keys.
public struct TypoToneCorrector: Sendable {
    /// Corrects duplicate or conflicting tone keys in Telex.
    /// E.g. "toanfs" -> replaces 'f' with 's' -> "toán"
    public static func correctTelexTone(currentSyllable: inout VietnameseSyllable, newKey: Character) -> Bool {
        let toneKeys: [Character: ToneMark] = [
            "s": .acute,
            "f": .grave,
            "r": .hook,
            "x": .tilde,
            "j": .dot
        ]

        let lower = Character(newKey.lowercased())
        guard let newTone = toneKeys[lower] else { return false }

        // If the syllable already had a tone and user presses another tone key, update tone
        if currentSyllable.tone != .none {
            if currentSyllable.tone == newTone {
                // If the same tone key is pressed again, some users intend to escape/undo tone
                // or just typed repeatedly. Standard behavior: keep or toggle off.
                // In modern engines: repeat tone key leaves tone or removes tone.
                // Keeping the tone is standard unless z is pressed.
            } else {
                currentSyllable.tone = newTone
                return true
            }
        } else {
            currentSyllable.tone = newTone
            return true
        }

        return false
    }

    /// Corrects duplicate or conflicting tone keys in VNI (1..5, 0).
    public static func correctVNITone(currentSyllable: inout VietnameseSyllable, newKey: Character) -> Bool {
        let vniTones: [Character: ToneMark] = [
            "1": .acute,
            "2": .grave,
            "3": .hook,
            "4": .tilde,
            "5": .dot
        ]

        guard let newTone = vniTones[newKey] else { return false }
        currentSyllable.tone = newTone
        return true
    }

    /// Standardizes the tone placement of an existing syllable.
    public static func standardizeTonePlacement(_ word: String, placement: TonePlacement) -> String {
        let parsed = SyllableParser.parse(word, tonePlacement: placement)
        return parsed.formattedString()
    }
}
