import Foundation
import NaturalLanguage
import AppKit
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
@Generable
public struct OnDeviceAISuggestions: Sendable {
    @Guide(description: "The corrected Vietnamese sentence with missing diacritics restored, keyboard typos fixed according to sentence meaning (e.g. 'to đang' -> 'Tôi đang', 'không cau' -> 'không dấu', 'thaat sư' -> 'thật sự'), and at most one missing bridge word inserted. Preserve word order and English technical terms (text, suggest, value, model, AI, app, code, bug, user, UI).")
    public var polishedSentence: String

    @Guide(description: "1 or 2 natural next words that follow the end of the sentence")
    public var nextWord: String
}
#endif

/// Result returned by the Apple On-Device Neural Engine (`FoundationModels` + `NaturalLanguage` + `NSSpellChecker`).
public struct OnDeviceAIResult: Equatable, Sendable {
    public let polishedSentence: String
    public let nextWord: String

    public init(polishedSentence: String, nextWord: String) {
        self.polishedSentence = polishedSentence
        self.nextWord = nextWord
    }
}

/// Real-time telemetry snapshot for the Apple On-Device Neural Engine pipeline.
public struct OnDeviceAITelemetry: Equatable, Sendable {
    public let isFoundationModelAvailable: Bool
    public let isNeuralPolishEnabled: Bool
    public let cachedEntries: Int
    public let maxCacheEntries: Int
    public let totalInferences: Int
    public let lastLatencyMs: Double

    public init(
        isFoundationModelAvailable: Bool,
        isNeuralPolishEnabled: Bool,
        cachedEntries: Int,
        maxCacheEntries: Int,
        totalInferences: Int,
        lastLatencyMs: Double
    ) {
        self.isFoundationModelAvailable = isFoundationModelAvailable
        self.isNeuralPolishEnabled = isNeuralPolishEnabled
        self.cachedEntries = cachedEntries
        self.maxCacheEntries = maxCacheEntries
        self.totalInferences = totalInferences
        self.lastLatencyMs = lastLatencyMs
    }
}

/// Apple On-Device AI Engine combining:
/// 1. Synchronous `<1ms` predictive word completions via `NSSpellChecker` & `NaturalLanguage` (`NLLanguageRecognizer`).
/// 2. Asynchronous Neural Engine LLM inference via Apple `FoundationModels` (`SystemLanguageModel` / `LanguageModelSession`).
public actor OnDeviceAIEngine {
    public static let shared = OnDeviceAIEngine()

    /// User-controlled toggle in Control Center to enable/disable background FoundationModels Neural Polish.
    public nonisolated(unsafe) static var isNeuralPolishEnabled: Bool = true

    private var cache: [String: OnDeviceAIResult] = [:]
    private let maxCacheEntries = 128
    private var totalInferencesCount: Int = 0
    private var lastInferenceLatencyMs: Double = 0.0

    private static let systemInstructions = """
    You are an expert Vietnamese and English keyboard input & typo corrector.
    1. Restore missing Vietnamese tone marks and diacritics on unsigned words (e.g. "toi dang thu go tieng viet khong dau" -> "Tôi đang thử gõ tiếng Việt không dấu").
    2. Fix character-level Vietnamese typing and spelling errors according to sentence meaning and context (e.g. "to đang thu go tieng viet không cau" -> "Tôi đang thử gõ tiếng Việt không dấu", "thaat sư không tốt lắm" -> "thật sự không tốt lắm").
    3. Insert at most one missing bridge word if the Vietnamese grammar requires it.
    4. Never expand "go" into "Google" (in Vietnamese "go" is "gõ"). Preserve word order and keep English technical terms (text, suggest, value, model, AI, app, code, bug, user, UI) in English.
    """

    public init() {}

    /// Returns true if Apple On-Device Foundation Models (`SystemLanguageModel`) is available on this Mac's Neural Engine.
    public nonisolated static var isFoundationModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    /// Prewarms the Apple Neural Engine language model session on startup to minimize first-token latency.
    public func prewarm() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), Self.isFoundationModelAvailable {
            let session = LanguageModelSession(instructions: Self.systemInstructions)
            session.prewarm()
        }
        #endif
    }

    /// Synchronous `<1ms` on-device predictive word completion using macOS `NSSpellChecker` for Vietnamese ("vi") and English ("en").
    @MainActor
    public static func spellCheckerCompletions(
        partialWord: String,
        fullSentence: String,
        limit: Int = 3
    ) -> [String] {
        let trimmed = partialWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let contextString = fullSentence.isEmpty ? trimmed : fullSentence
        let nsContext = contextString as NSString
        let range = nsContext.range(of: trimmed, options: .backwards)
        guard range.location != NSNotFound else { return [] }

        let checker = NSSpellChecker.shared
        var results: [String] = []
        var seen: Set<String> = [trimmed.lowercased()]

        // Query Vietnamese ("vi") first, then English ("en")
        for lang in ["vi", "en"] {
            if let completions = checker.completions(
                forPartialWordRange: range,
                in: contextString,
                language: lang,
                inSpellDocumentWithTag: 0
            ) {
                for cand in completions {
                    let clean = cand.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lower = clean.lowercased()
                    if clean.count > trimmed.count && !seen.contains(lower) {
                        seen.insert(lower)
                        results.append(clean)
                        if results.count >= limit {
                            return results
                        }
                    }
                }
            }
        }
        return results
    }

    /// Runs on-device Neural Engine LLM inference (`FoundationModels`) to restore diacritics across arbitrary Vietnamese/English sentences
    /// and predict the next contextual word.
    public func inferSentencePolishAndNextWord(
        rawSentence: String,
        tone: PolishTone = .natural
    ) async -> OnDeviceAIResult? {
        guard Self.isNeuralPolishEnabled else { return nil }
        let trimmed = rawSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        guard wordCount >= 2 && wordCount <= 16 else { return nil }

        // First pass: fast deterministic rule-based polisher
        let basePolished = VietnameseTextPolisher.polish(trimmed, tone: tone)
        let cacheKey = "\(tone.rawValue)|\(basePolished.lowercased())"
        if let cached = cache[cacheKey] {
            return cached
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), Self.isFoundationModelAvailable {
            do {
                let startClock = CFAbsoluteTimeGetCurrent()
                let session = LanguageModelSession(instructions: Self.systemInstructions)
                let options = GenerationOptions(samplingMode: .greedy)
                let response = try await session.respond(
                    to: "Correct Vietnamese typos and restore missing diacritics according to sentence meaning: \(basePolished)",
                    generating: OnDeviceAISuggestions.self,
                    options: options
                )
                let elapsedMs = max(1.0, (CFAbsoluteTimeGetCurrent() - startClock) * 1000.0)
                lastInferenceLatencyMs = elapsedMs
                totalInferencesCount += 1

                var candidate = response.content.polishedSentence
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "bộ Go", with: "bộ gõ")
                    .replacingOccurrences(of: "thử Google", with: "thử gõ")
                    .replacingOccurrences(of: "Google tiếng Việt", with: "gõ tiếng Việt")

                // Apply deterministic Vietnamese collocation & typo polisher pass on top of LLM output
                candidate = VietnameseTextPolisher.polish(candidate, tone: tone)

                // Remove trailing period added by LLM if original input had no trailing punctuation
                if !trimmed.hasSuffix(".") && candidate.hasSuffix(".") {
                    candidate.removeLast()
                }

                // Token-Preservation Guard: ensure the LLM did not drop any existing word from `basePolished`
                let validatedPolished: String
                if Self.isValidRefinement(base: basePolished, candidate: candidate) {
                    validatedPolished = candidate
                } else {
                    validatedPolished = basePolished
                }

                let cleanNext = response.content.nextWord
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .punctuationCharacters)

                let res = OnDeviceAIResult(
                    polishedSentence: validatedPolished,
                    nextWord: cleanNext
                )
                storeCache(key: cacheKey, value: res)
                return res
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    private func storeCache(key: String, value: OnDeviceAIResult) {
        if cache.count >= maxCacheEntries {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = value
    }

    /// Returns a snapshot of current on-device AI telemetry metrics.
    public func telemetry() -> OnDeviceAITelemetry {
        OnDeviceAITelemetry(
            isFoundationModelAvailable: Self.isFoundationModelAvailable,
            isNeuralPolishEnabled: Self.isNeuralPolishEnabled,
            cachedEntries: cache.count,
            maxCacheEntries: maxCacheEntries,
            totalInferences: totalInferencesCount,
            lastLatencyMs: lastInferenceLatencyMs
        )
    }

    /// Clears the in-memory LRU inference cache.
    public func clearCache() {
        cache.removeAll(keepingCapacity: true)
    }

    /// Verifies that the Neural Engine candidate preserves all existing words from `base`
    /// (allowing unsigned -> signed Vietnamese diacritic restoration and at most 1 inserted bridge word).
    public nonisolated static func isValidRefinement(base: String, candidate: String) -> Bool {
        let baseTokens = base
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }
        let candTokens = candidate
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }

        // Remove filler words from base when checking length bounds
        let cleanBase = VietnameseTextPolisher.removeFillers(base)
        let cleanBaseTokens = cleanBase
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty && !VietnameseTextPolisher.singleWordFillers.contains($0) }

        let effectiveBaseTokens = cleanBaseTokens.isEmpty ? baseTokens : cleanBaseTokens

        guard !candTokens.isEmpty,
              candTokens.count >= effectiveBaseTokens.count,
              candTokens.count <= baseTokens.count + 2 else {
            return false
        }

        let candStripped = candTokens.map { SuggestionEngine.stripDiacritics($0) }
        var closeMatches = 0

        // Every token in effectiveBaseTokens must have its ASCII root or a character-level typo correction (edit distance <= 2) present in candidate
        for bTok in effectiveBaseTokens {
            let bRoot = SuggestionEngine.stripDiacritics(bTok)
            let hasExactOrTypoMatch = candStripped.contains { cRoot in
                cRoot == bRoot || SuggestionEngine.asciiEditDistance(bRoot, cRoot) <= 2
            }
            guard hasExactOrTypoMatch else {
                return false
            }
            if candStripped.contains(where: { $0 == bRoot || SuggestionEngine.asciiEditDistance(bRoot, $0) <= 1 }) {
                closeMatches += 1
            }
        }

        // At least 65% of effective base tokens must be exact root matches or 1-character typo fixes
        guard Double(closeMatches) / Double(effectiveBaseTokens.count) >= 0.65 else {
            return false
        }

        // Any already-accented Vietnamese word in base must retain its exact token or exact stripped root in candidate
        // (Do NOT allow 1-character edit distance substitutions to corrupt accented words like "câu" -> "dấu"!)
        for bTok in effectiveBaseTokens {
            let hasDiacritics = bTok.unicodeScalars.contains { $0.value > 127 }
            if hasDiacritics {
                let bRoot = SuggestionEngine.stripDiacritics(bTok)
                let preserved = candTokens.contains(bTok) || candStripped.contains(bRoot)
                if !preserved {
                    return false
                }
            }
        }
        return true
    }
}
