import Foundation

/// Result emitted by `VietnameseInputEngine` after processing each keystroke.
public struct EngineResult: Equatable, Sendable {
    /// Whether the key was handled by the Vietnamese input engine.
    public var consumed: Bool
    /// Number of backspaces required to erase previous characters from the active text field.
    public var backspaceCount: Int
    /// Replacement text to insert into the active text field.
    public var replacementText: String
    /// Current formatted word held in buffer.
    public var currentWord: String

    public init(
        consumed: Bool = false,
        backspaceCount: Int = 0,
        replacementText: String = "",
        currentWord: String = ""
    ) {
        self.consumed = consumed
        self.backspaceCount = backspaceCount
        self.replacementText = replacementText
        self.currentWord = currentWord
    }
}

/// Finite State Machine engine for Telex & VNI Vietnamese input.
public final class VietnameseInputEngine: @unchecked Sendable {
    public var inputMethod: InputMethod
    public var tonePlacement: TonePlacement
    public var autoEnglishRestore: Bool

    // Internal state buffers
    private var rawBuffer: [Character] = []
    private var currentFormattedWord: String = ""
    /// Tracks whether the immediately preceding word was English to disambiguate short homographs (e.g. "is", "car", "var", "now").
    public var previousWordWasEnglish: Bool = false

    public init(
        inputMethod: InputMethod = .telex,
        tonePlacement: TonePlacement = .modern,
        autoEnglishRestore: Bool = true
    ) {
        self.inputMethod = inputMethod
        self.tonePlacement = tonePlacement
        self.autoEnglishRestore = autoEnglishRestore
    }

    /// Resets the internal state buffer.
    public func reset() {
        rawBuffer.removeAll()
        currentFormattedWord = ""
    }

    /// Returns the current raw input buffer as a string.
    public var rawString: String {
        String(rawBuffer)
    }

    /// Returns the current word as formatted by the engine.
    public var formattedWord: String {
        currentFormattedWord
    }

    /// Computes minimal backspace count and suffix replacement between oldDisplayed and newDisplayed.
    public static func minimalDelta(from oldWord: String, to newWord: String) -> (backspaces: Int, replacement: String) {
        let oldChars = Array(oldWord)
        let newChars = Array(newWord)
        var commonLen = 0
        let minLen = min(oldChars.count, newChars.count)
        while commonLen < minLen && oldChars[commonLen] == newChars[commonLen] {
            commonLen += 1
        }
        let backspaces = oldChars.count - commonLen
        let replacement = String(newChars.dropFirst(commonLen))
        return (backspaces, replacement)
    }

    /// Handles a backspace keystroke by deleting the last displayed character on screen and keeping the buffer in sync.
    public func handleBackspace() -> EngineResult {
        guard !currentFormattedWord.isEmpty else {
            reset()
            return EngineResult(consumed: false)
        }

        let newWord = String(currentFormattedWord.dropLast())
        currentFormattedWord = newWord
        rawBuffer = Array(newWord)
        return EngineResult(consumed: false, backspaceCount: 0, replacementText: "", currentWord: newWord)
    }

    /// Processes a typed character.
    public func processKey(_ char: Character) -> EngineResult {
        if inputMethod == .off {
            return handlePassThrough(char)
        }

        // Word boundary delimiters: Space, Enter, tabs, punctuation
        if isWordBoundary(char) {
            return handleWordBoundary(char)
        }

        let previousWord = currentFormattedWord
        rawBuffer.append(char)

        let newWord = reprocess(rawBuffer)
        currentFormattedWord = newWord

        if newWord != previousWord + String(char) {
            // Modification took place (e.g. 'a' + 'a' -> 'â', or 'toan' + 's' -> 'toán')
            let delta = Self.minimalDelta(from: previousWord, to: newWord)
            return EngineResult(
                consumed: true,
                backspaceCount: delta.backspaces,
                replacementText: delta.replacement,
                currentWord: newWord
            )
        }

        // Normal letter addition without transformation
        return EngineResult(
            consumed: false,
            backspaceCount: 0,
            replacementText: "",
            currentWord: newWord
        )
    }

    // MARK: - Private Processing Logic

    private func handlePassThrough(_ char: Character) -> EngineResult {
        if isWordBoundary(char) {
            let completed = currentFormattedWord
            reset()
            return EngineResult(consumed: false, currentWord: completed)
        } else {
            rawBuffer.append(char)
            currentFormattedWord.append(char)
        }
        return EngineResult(consumed: false, currentWord: currentFormattedWord)
    }

    private func handleWordBoundary(_ boundaryChar: Character) -> EngineResult {
        let rawWord = String(rawBuffer)
        let formatted = currentFormattedWord

        defer {
            reset()
        }

        guard !rawWord.isEmpty else {
            return EngineResult(consumed: false, backspaceCount: 0, replacementText: "", currentWord: "")
        }

        let lowerRaw = rawWord.lowercased()

        // Auto-Diacritic & Shorthand Restore on Space for unambiguous unsigned Vietnamese words (e.g. "duoc" -> "được", "dduoc" -> "được", "khong"/"ko" -> "không", "chua" -> "chưa", "tot" -> "tốt")
        let autoDiacriticMap: [String: String] = [
            "duoc": "được",
            "dduoc": "được",
            "dc": "được",
            "đc": "được",
            "khong": "không",
            "ko": "không",
            "nhung": "nhưng",
            "chua": "chưa",
            "nguoi": "người",
            "truoc": "trước",
            "trc": "trước",
            "ntn": "như thế nào",
            "mn": "mọi người",
            "tot": "tốt",
            "hoat": "hoạt",
            "thuc": "thực",
            "viec": "việc",
            "phai": "phải",
            "biet": "biết",
            "muon": "muốn",
            "cung": "cũng",
            "nhieu": "nhiều",
            "luon": "luôn"
        ]
        // Contextual Vietnamese unsigned words restored on Space when already in a Vietnamese sentence (!previousWordWasEnglish)
        let contextualVietnameseUnsignedMap: [String: String] = [
            "co": "có",
            "dang": "đang",
            "dong": "động"
        ]
        // User-customizable macros from Control Center take highest priority on Space when enabled
        let customMacroMatch: String? = CustomMacroRegistry.shared.expandMacrosOnSpace
            ? (CustomMacroRegistry.shared.lookup(formatted) ?? CustomMacroRegistry.shared.lookup(lowerRaw))
            : nil
        let candidateAutoVN = customMacroMatch ?? autoDiacriticMap[lowerRaw] ?? (!previousWordWasEnglish ? contextualVietnameseUnsignedMap[lowerRaw] : nil)
        if boundaryChar == " ",
           let rawRestoredVN = candidateAutoVN {
            let restoredVN: String = {
                if customMacroMatch != nil { return rawRestoredVN }
                let letters = formatted.filter { $0.isLetter }
                if letters.count >= 2 && letters.allSatisfy({ $0.isUppercase }) {
                    return rawRestoredVN.uppercased()
                } else if let first = formatted.first, first.isUppercase, let rFirst = rawRestoredVN.first {
                    return rFirst.uppercased() + rawRestoredVN.dropFirst()
                }
                return rawRestoredVN
            }()
            if formatted != restoredVN {
                previousWordWasEnglish = false
                let backspaces = formatted.count
                let replacement = restoredVN + String(boundaryChar)
                return EngineResult(
                    consumed: true,
                    backspaceCount: backspaces,
                    replacementText: replacement,
                    currentWord: restoredVN
                )
            }
        }

        let isEnglish = SmartEnglishDetector.isEnglishWord(rawWord, previousWordWasEnglish: previousWordWasEnglish)
        let isValidVN = SyllableParser.isValidVietnameseSyllable(raw: rawWord, formatted: formatted, isWordBoundary: true)
        let hasDoubleEscape = Self.collapseDoubleTelexEscape(rawWord) != nil
        let shouldRestore: Bool = {
            guard autoEnglishRestore && !hasDoubleEscape else { return false }
            if inputMethod == .vni && rawWord.contains(where: { "123456789".contains($0) }) {
                // In VNI mode, if the user explicitly typed numeric tone/modifier keys (e.g. a6 -> â, a8 -> ă, o7 -> ơ),
                // do NOT restore on word boundary unless it's an explicit English word.
                return isEnglish
            }
            return isEnglish || !isValidVN
        }()

        // Update contextual bilingual momentum for the next word in the sentence
        let englishConnectors: Set<String> = [
            "a", "i", "an", "the", "and", "are", "you", "not", "can", "all", "one",
            "out", "day", "get", "has", "him", "his", "how", "man", "new", "now",
            "old", "see", "two", "way", "who", "did", "its", "let", "put", "say",
            "she", "too", "use", "our", "in", "on", "at", "to", "of", "by", "if"
        ]
        if shouldRestore || isEnglish {
            previousWordWasEnglish = true
        } else if formatted != rawWord {
            // Word was transformed with Vietnamese diacritics
            previousWordWasEnglish = false
        } else if englishConnectors.contains(lowerRaw) {
            // Keep or activate English momentum on standard English articles/connectors
            if previousWordWasEnglish || ["the", "and", "are", "you", "our"].contains(lowerRaw) {
                previousWordWasEnglish = true
            }
        } else {
            previousWordWasEnglish = false
        }

        // Auto-English Restore when pressing Space or punctuation
        if shouldRestore && formatted != rawWord {
            let backspaces = formatted.count
            let replacement = rawWord + String(boundaryChar)
            return EngineResult(
                consumed: true,
                backspaceCount: backspaces,
                replacementText: replacement,
                currentWord: rawWord
            )
        }

        return EngineResult(consumed: false, backspaceCount: 0, replacementText: "", currentWord: formatted)
    }

    private func isWordBoundary(_ ch: Character) -> Bool {
        if inputMethod == .telex && ch.isNumber {
            return true
        }
        return ch.isWhitespace || ch.isPunctuation || ch.isSymbol || ch.isMathSymbol || ch.isCurrencySymbol || ch.isNewline || ch == "\t" || ch == "\r"
    }

    /// Core deterministic transformation of a raw keystroke buffer into Vietnamese text.
    public func reprocess(_ rawChars: [Character]) -> String {
        switch inputMethod {
        case .telex:
            return processTelex(rawChars)
        case .vni:
            return processVNI(rawChars)
        case .off:
            return String(rawChars)
        }
    }

    // MARK: - Telex Processing (Standard + Free-Order Telex + Real-Time Bilingual Validation)

    /// Collapses UniKey-style double Telex escape sequences ("xx" -> "x", "jj" -> "j", "ww" -> "w",
    /// and "rr" -> "r", "ss" -> "s", "ff" -> "f" when not a genuine English double-consonant word)
    /// so typing "arr" -> "ar", "arry" -> "ary", "ayrr" -> "ayr", "texxt" -> "text".
    public static func collapseDoubleTelexEscape(_ raw: String) -> String? {
        let lower = raw.lowercased()
        if lower.contains("www") {
            return nil
        }
        let hasAlwaysEscapeDouble = lower.contains("xx") || lower.contains("jj") || lower.contains("ww")
        let hasToneEscapeDouble = lower.contains("rr") || lower.contains("ss") || lower.contains("ff")
        guard hasAlwaysEscapeDouble || hasToneEscapeDouble else {
            return nil
        }
        if hasToneEscapeDouble && !hasAlwaysEscapeDouble {
            if SmartEnglishDetector.isGenuineEnglishDoubleConsonantWord(lower) {
                return nil
            }
        }
        var out = raw
        let escapePairs: [(String, String)] = [
            ("xx", "x"), ("XX", "X"), ("Xx", "X"), ("xX", "x"),
            ("jj", "j"), ("JJ", "J"), ("Jj", "J"), ("jJ", "j"),
            ("ww", "w"), ("WW", "W"), ("Ww", "W"), ("wW", "w"),
            ("rr", "r"), ("RR", "R"), ("Rr", "R"), ("rR", "r"),
            ("ss", "s"), ("SS", "S"), ("Ss", "S"), ("sS", "s"),
            ("ff", "f"), ("FF", "F"), ("Ff", "F"), ("fF", "f")
        ]
        for (doubleKey, singleKey) in escapePairs {
            out = out.replacingOccurrences(of: doubleKey, with: singleKey)
        }
        return out != raw ? out : nil
    }

    private func processTelex(_ chars: [Character]) -> String {
        guard !chars.isEmpty else { return "" }

        let rawString = String(chars)

        // 0a. Check UniKey-style double Telex escape ("xx" -> "x", "jj" -> "j", "ww" -> "w", e.g. "texx" -> "tex", "texxt" -> "text")
        if let escaped = Self.collapseDoubleTelexEscape(rawString) {
            let lower = escaped.lowercased()
            let hasModifiers = lower.contains("ee") || lower.contains("dd") || lower.contains("aa") ||
                               lower.contains("oo") || lower.contains("w")
            if hasModifiers {
                return processTelexInternal(Array(escaped), rawString: rawString)
            }
            return escaped
        }

        // 0b. Fast-path real-time English check (e.g. words starting with f, j, z, w+letter, st, sp, cl, cr, pr, or containing ea, ou, io, ss, ff, ll...)
        if autoEnglishRestore && SmartEnglishDetector.isDefinitelyEnglishInProgress(rawString) {
            return rawString
        }

        return processTelexInternal(chars, rawString: rawString)
    }

    private func processTelexInternal(_ chars: [Character], rawString: String) -> String {
        var result: [Character] = []
        var activeTone: ToneMark = .none
        var activeToneChar: Character? = nil
        var activeToneInsertIndex: Int? = nil

        let telexTones: [Character: ToneMark] = [
            "s": .acute,
            "f": .grave,
            "r": .hook,
            "x": .tilde,
            "j": .dot
        ]

        var i = 0
        while i < chars.count {
            let ch = chars[i]
            let lower = Character(ch.lowercased())
            let isUpper = ch.isUppercase

            // 1. Check adjacent 'dd' -> 'đ' (and 'ddd' -> 'dd')
            if lower == "d" && i + 1 < chars.count && Character(chars[i + 1].lowercased()) == "d" {
                if i + 2 < chars.count && Character(chars[i + 2].lowercased()) == "d" {
                    result.append(contentsOf: [chars[i], chars[i + 1]])
                    i += 3
                    continue
                }
                let shouldBeUpper = isUpper || chars[i + 1].isUppercase
                result.append(shouldBeUpper ? "Đ" : "đ")
                i += 2
                continue
            }

            // 1b. Free-order 'd' at end of word starting with 'd' ONLY when followed by a valid final consonant or horn/hat vowel
            // (e.g. "duocd" -> "được", "duongd" -> "đường", while keeping English "dad", "did", "dead" intact)
            if lower == "d" && result.count >= 3,
               let first = result.first,
               Character(first.lowercased()) == "d",
               let last = result.last,
               !VietnameseVowelMap.isVowel(last) || ["ư", "ơ", "ă", "â", "ê", "ô"].contains(Character(VietnameseVowelMap.stripTone(last).lowercased())) {
                result[0] = first.isUppercase ? "Đ" : "đ"
                i += 1
                continue
            }

            // 2. Check adjacent double vowel 'aa'->'â', 'ee'->'ê', 'oo'->'ô' (and triple revert)
            if (lower == "a" || lower == "e" || lower == "o") && i + 1 < chars.count && Character(chars[i + 1].lowercased()) == lower {
                if i + 2 < chars.count && Character(chars[i + 2].lowercased()) == lower {
                    result.append(contentsOf: [chars[i], chars[i + 1]])
                    i += 3
                    continue
                }
                let modified = VietnameseVowelMap.applyModification(ch, mod: .hat)
                result.append(modified)
                i += 2
                continue
            }

            // 2b. Free-order hat vowel ONLY for valid Vietnamese diphthongs (e.g. "toio" -> "tôi", "caua" -> "câu", "tienges" -> "tiếng", "vietej" -> "việt")
            // Prevents corrupting English multi-syllable words like "data", "java", "delete", "select", "create", "here", "where", "more", "code"
            if lower == "a" || lower == "e" || lower == "o" {
                if let matchIdx = result.lastIndex(where: { Character($0.lowercased()) == lower }),
                   matchIdx < result.count - 1 {
                    let intervening = result[(matchIdx + 1)..<result.count]
                    let allInterveningAreVowels = intervening.allSatisfy { VietnameseVowelMap.isVowel($0) }
                    let isCompoundDiphthongBeforeConsonant: Bool = {
                        guard matchIdx > 0 else { return false }
                        let prevVowel = Character(VietnameseVowelMap.stripTone(result[matchIdx - 1]).lowercased())
                        if lower == "e" && (prevVowel == "i" || prevVowel == "y" || prevVowel == "u") {
                            return true // e.g. "tieng" + "e" -> "tiêng", "viet" + "e" -> "viêt"
                        }
                        if lower == "o" && (prevVowel == "u" || prevVowel == "ư") {
                            return true // e.g. "muon" + "o" -> "muôn", "cuoc" + "o" -> "cuôc"
                        }
                        return false
                    }()

                    if allInterveningAreVowels || isCompoundDiphthongBeforeConsonant {
                        result[matchIdx] = VietnameseVowelMap.applyModification(result[matchIdx], mod: .hat)
                        i += 1
                        continue
                    }
                }
            }

            // 3. Check 'w' (horn / breve): supports adjacent ("uw", "ow", "aw"), fast-roll ("wu"->"ư", "wo"->"ơ", "wa"->"ă" e.g. "ddwuocj"->"được"), and free-order ("chuaw" -> "chưa", "duocw" -> "được")
            if lower == "w" {
                if !result.isEmpty && !result.contains(where: { VietnameseVowelMap.isVowel($0) }) && i + 1 < chars.count {
                    let nextChar = chars[i + 1]
                    let nextLower = Character(nextChar.lowercased())
                    if nextLower == "u" || nextLower == "o" {
                        result.append(VietnameseVowelMap.applyModification(nextChar, mod: .horn))
                        i += 2
                        continue
                    } else if nextLower == "a" {
                        result.append(VietnameseVowelMap.applyModification(nextChar, mod: .breve))
                        i += 2
                        continue
                    }
                }
                if applyTelexW(to: &result) {
                    i += 1
                    continue
                } else if !result.contains(where: { VietnameseVowelMap.isVowel($0) }) {
                    // Standalone 'w' -> 'ư' ONLY when no vowels exist yet in result (e.g. "w" -> "ư", "nhw" -> "như", "thw" -> "thư")
                    // Preserves English "new", "few", "view", "review" where 'e'/'ie' is already present!
                    result.append(isUpper ? "Ư" : "ư")
                    i += 1
                    continue
                }
            }

            // 4. Tone keys: s, f, r, x, j, z
            if lower == "z" {
                let hasVowelInResult = result.contains { VietnameseVowelMap.isVowel($0) }
                let hasTonedVowel = result.contains { VietnameseVowelMap.extractTone($0) != .none }
                if hasVowelInResult && (activeTone != .none || hasTonedVowel) {
                    activeTone = .none
                    for idx in 0..<result.count {
                        if VietnameseVowelMap.isVowel(result[idx]) {
                            result[idx] = VietnameseVowelMap.stripTone(result[idx])
                        }
                    }
                    i += 1
                    continue
                }
            }

            if let tone = telexTones[lower] {
                let hasVowelInResult = result.contains { VietnameseVowelMap.isVowel($0) }
                if hasVowelInResult {
                    let prefixLower = String(result).lowercased()
                    let isQuOrGiInitial = (prefixLower == "qu" || prefixLower == "gi")
                    let hasModifiedVowelInResult = result.contains {
                        ["ă", "â", "ê", "ô", "ơ", "ư", "đ"].contains(Character(VietnameseVowelMap.stripTone($0).lowercased()))
                    }
                    let nextIsVowel = (i + 1 < chars.count) && VietnameseVowelMap.isVowel(chars[i + 1])

                    if activeTone == tone && !hasModifiedVowelInResult, let origChar = activeToneChar {
                        // Pressing the same tone key a second time escapes the tone and restores the single literal character
                        activeTone = .none
                        activeToneChar = nil
                        if let insertIdx = activeToneInsertIndex, insertIdx <= result.count {
                            result.insert(origChar, at: insertIdx)
                        } else {
                            result.append(origChar)
                        }
                        activeToneInsertIndex = nil
                        i += 1
                        continue
                    } else if !nextIsVowel || isQuOrGiInitial || hasModifiedVowelInResult {
                        activeTone = tone
                        activeToneChar = ch
                        activeToneInsertIndex = result.count
                        i += 1
                        continue
                    }
                } else if !result.isEmpty, i + 1 < chars.count, VietnameseVowelMap.isVowel(chars[i + 1]) {
                    // Fast-roll tolerance: if user's index finger hits tone ('f', 's', 'j', 'x', 'r') right before vowel ('a', 'o', 'e'...)
                    // e.g. "vfa" -> "và", "lfa" -> "là", "mfa" -> "mà" (unless it forms a valid initial like "tr")
                    let prefixLower = String(result).lowercased()
                    let isCompoundTr = (prefixLower == "t" && lower == "r")
                    if !isCompoundTr {
                        activeTone = tone
                        activeToneChar = ch
                        activeToneInsertIndex = result.count
                        i += 1
                        continue
                    }
                }
            }

            // Default: append character as-is
            result.append(ch)
            i += 1
        }

        // Normalize 'uo' + horn combinations (e.g. 'ưo' or 'uơ' -> 'ươ' when followed by final consonant or in standard 'ươ' words)
        var normalizedResult = result
        if normalizedResult.count >= 2 {
            for k in 0..<(normalizedResult.count - 1) {
                let c1 = normalizedResult[k]
                let c2 = normalizedResult[k + 1]
                let l1 = Character(c1.lowercased())
                let l2 = Character(c2.lowercased())
                let hasCharAfter = (k + 2) < normalizedResult.count

                // "uơ" -> "ươ" (unless initial is "qu", or "th"/"h" open syllables without final consonants e.g. "quơ", "thuở", "huơ")
                let startsWithSpecialOpenUo = (normalizedResult.count >= 2 &&
                    String(normalizedResult.prefix(2)).lowercased() == "qu" && k == 1) ||
                    (!hasCharAfter && k == 2 && String(normalizedResult.prefix(2)).lowercased() == "th") ||
                    (!hasCharAfter && k == 1 && String(normalizedResult.prefix(1)).lowercased() == "h")

                if !startsWithSpecialOpenUo {
                    if l1 == "u" && l2 == "ơ" {
                        normalizedResult[k] = c1.isUppercase ? "Ư" : "ư"
                    } else if l1 == "ư" && l2 == "o" && hasCharAfter {
                        normalizedResult[k + 1] = c2.isUppercase ? "Ơ" : "ơ"
                    }
                }
            }
        }

        let intermediateWord = String(normalizedResult)
        var parsed = SyllableParser.parse(intermediateWord, tonePlacement: tonePlacement)
        if activeTone != .none {
            parsed.tone = activeTone
        }

        // Fast-typing typo recovery: in Vietnamese, a syllable with a modified vowel (ô, ơ, ư, ă, â, ê)
        // can never end in bare 'g' without 'n' ('ng'). Complete 'g' -> 'ng' (e.g. "khoog" -> "không", "nhuwg" -> "nhưng").
        if parsed.finalConsonant.lowercased() == "g" && parsed.initialConsonant.lowercased() != "g" {
            let modifiedVowels: Set<Character> = ["ô", "ơ", "ư", "ă", "â", "ê"]
            let hasModifiedVowel = parsed.vowels.contains { modifiedVowels.contains(Character(VietnameseVowelMap.stripTone($0).lowercased())) }
            if hasModifiedVowel {
                parsed.finalConsonant = parsed.finalConsonant == "G" ? "NG" : "ng"
            }
        }

        let candidate = parsed.formattedString()

        // 5. Real-time Vietnamese Phonotactic & Orthographic Validation:
        // If transformation produced a structurally impossible Vietnamese syllable (e.g. "english", "support", "system", "world", "work", "user", "more", "here", "part", "left", "next"),
        // immediately revert to the raw English string in real-time!
        if autoEnglishRestore && candidate != rawString {
            if !SyllableParser.isValidVietnameseSyllable(raw: rawString, formatted: candidate, isWordBoundary: false) {
                return rawString
            }
        }

        return candidate
    }

    /// Applies 'w' transformation to the current `result` buffer (handling `uo`->`ươ`, `ua`->`ưa`, and single `u`/`o`/`a`).
    private func applyTelexW(to result: inout [Character]) -> Bool {
        guard !result.isEmpty else { return false }

        let lowerStr = String(result).lowercased()
        let startsWithQu = lowerStr.hasPrefix("qu")

        // Case 1: Check for 'u' + 'o'/'ô'/'ơ' pair in result -> 'ư' + 'ơ' (unless 'qu' + 'o' -> 'quơ' or 'th'/'h' open syllable -> 'uơ')
        if result.count >= 2 {
            for idx in 0..<(result.count - 1) {
                let c1 = Character(result[idx].lowercased())
                let c2 = Character(result[idx + 1].lowercased())
                if (c1 == "u" || c1 == "ư") && (c2 == "o" || c2 == "ơ" || c2 == "ô") {
                    let isSpecialOpenSyllable = (startsWithQu && idx == 1) ||
                        (idx == 2 && lowerStr.hasPrefix("th")) ||
                        (idx == 1 && lowerStr.hasPrefix("h"))
                    if isSpecialOpenSyllable {
                        result[idx + 1] = VietnameseVowelMap.applyModification(result[idx + 1], mod: .horn)
                    } else {
                        result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .horn)
                        result[idx + 1] = VietnameseVowelMap.applyModification(result[idx + 1], mod: .horn)
                    }
                    return true
                }
            }
        }

        // Case 2: Check for 'u' + 'a' pair in result -> 'ưa' (e.g. "chua" + "w" -> "chưa", unless "qua" + "w" -> "quă")
        if result.count >= 2 {
            for idx in 0..<(result.count - 1) {
                let c1 = Character(result[idx].lowercased())
                let c2 = Character(result[idx + 1].lowercased())
                if c1 == "u" && c2 == "a" {
                    if startsWithQu && idx == 1 {
                        result[idx + 1] = VietnameseVowelMap.applyModification(result[idx + 1], mod: .breve)
                    } else {
                        result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .horn)
                    }
                    return true
                }
            }
        }

        // Case 3: Search backward for 'o', 'u', or 'a' to modify (supports both adjacent and post-consonant e.g. "namw" -> "năm")
        for idx in stride(from: result.count - 1, through: 0, by: -1) {
            let lower = Character(result[idx].lowercased())
            if lower == "o" {
                result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .horn)
                return true
            } else if lower == "u" {
                if !(startsWithQu && idx == 1) {
                    result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .horn)
                    return true
                }
            } else if lower == "a" {
                result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .breve)
                return true
            } else if lower == "ư" || lower == "ơ" || lower == "ă" {
                // Already modified (e.g. second 'w' in "dduwowngf" where 'ư' was already modified)
                return true
            }
        }

        return false
    }

    // MARK: - VNI Processing

    private func processVNI(_ chars: [Character]) -> String {
        guard !chars.isEmpty else { return "" }

        var result: [Character] = []
        var activeTone: ToneMark = .none
        var removeToneRequested = false

        let vniTones: [Character: ToneMark] = [
            "1": .acute,
            "2": .grave,
            "3": .hook,
            "4": .tilde,
            "5": .dot
        ]

        var i = 0
        while i < chars.count {
            let ch = chars[i]

            if ch == "0" {
                activeTone = .none
                removeToneRequested = true
                for idx in 0..<result.count {
                    if VietnameseVowelMap.isVowel(result[idx]) {
                        result[idx] = VietnameseVowelMap.stripTone(result[idx])
                    }
                }
                i += 1
                continue
            }

            if let tone = vniTones[ch] {
                let hasVowelInResult = result.contains { VietnameseVowelMap.isVowel($0) }
                if hasVowelInResult {
                    activeTone = tone
                    removeToneRequested = false
                    i += 1
                    continue
                }
            }

            if ch == "6" {
                if let idx = result.lastIndex(where: { ["a", "e", "o"].contains(Character($0.lowercased())) }) {
                    result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .hat)
                    i += 1
                    continue
                }
            } else if ch == "7" {
                if applyTelexW(to: &result) {
                    i += 1
                    continue
                }
            } else if ch == "8" {
                if let idx = result.lastIndex(where: { Character($0.lowercased()) == "a" }) {
                    result[idx] = VietnameseVowelMap.applyModification(result[idx], mod: .breve)
                    i += 1
                    continue
                }
            } else if ch == "9" {
                if let idx = result.firstIndex(where: { Character($0.lowercased()) == "d" }) {
                    result[idx] = result[idx].isUppercase ? "Đ" : "đ"
                    i += 1
                    continue
                }
            }

            result.append(ch)
            i += 1
        }

        let intermediateWord = String(result)
        var parsed = SyllableParser.parse(intermediateWord, tonePlacement: tonePlacement)
        if removeToneRequested {
            parsed.tone = .none
        } else if activeTone != .none {
            parsed.tone = activeTone
        }
        return parsed.formattedString()
    }
}
