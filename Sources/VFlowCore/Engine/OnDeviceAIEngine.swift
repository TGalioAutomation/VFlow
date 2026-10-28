import Foundation
import NaturalLanguage
import AppKit
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
@Generable
public struct OnDeviceAISuggestions: Sendable {
    @Guide(description: "The corrected Vietnamese sentence with missing diacritics restored, keyboard typos fixed according to sentence meaning and System Prompt instructions (e.g. 'to đang' -> 'Tôi đang', 'không cau' -> 'không dấu', 'thaat sư' -> 'thật sự'), and at most one missing bridge word inserted. Preserve word order and English technical terms (text, suggest, value, model, AI, app, code, bug, user, UI).")
    public var polishedSentence: String

    @Guide(description: "1 or 2 natural next words that follow the end of the sentence")
    public var nextWord: String

    @Guide(description: "Urgency/severity of correction needed: 0 = input is already clean and compliant, 1 = minor 1-word accent or tone tweak, 2 = heavy spelling errors, missing diacritics across multiple words, or violates System Prompt rules")
    public var severityLevel: Int
}
#endif

/// Visual urgency/severity level indicating how much the current input needs correction or deviates from the System Prompt.
public enum SuggestionSeverity: Int, Comparable, Equatable, Codable, Sendable {
    /// Clean input or standard prefix/next-word completion (Cyan `#38BDF8`).
    case normal = 0
    /// Minor 1-word typo/diacritic fix or stylistic adjustment (Amber `#FBBF24`).
    case moderate = 1
    /// Heavy spelling errors (>=2 misspelled/unsigned words) or System Prompt rule deviation (Rose `#FB7185`).
    case high = 2

    public static func < (lhs: SuggestionSeverity, rhs: SuggestionSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Built-in & customizable System Prompt profiles controlling AI suggestion style and compliance checking.
public enum SystemPromptPreset: String, CaseIterable, Identifiable, Equatable, Sendable {
    case standard = "standard"
    case formalEmail = "formalEmail"
    case developerIT = "developerIT"
    case concise = "concise"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard:
            return "Mặc định (Tự nhiên)"
        case .formalEmail:
            return "Công sở / Email"
        case .developerIT:
            return "Kỹ thuật / Dev IT"
        case .concise:
            return "Ngắn gọn / Súc tích"
        case .custom:
            return "Tùy chỉnh (Custom)"
        }
    }

    public var subtitle: String {
        switch self {
        case .standard:
            return "Sửa lỗi chính tả, thêm dấu Tiếng Việt chuẩn ngữ cảnh & tự nhiên"
        case .formalEmail:
            return "Chặn teencode/viết tắt, ưu tiên câu lịch sự & chuẩn mực công sở"
        case .developerIT:
            return "Sửa dấu Tiếng Việt nhưng bảo toàn tuyệt đối thuật ngữ code/IT"
        case .concise:
            return "Lược bỏ từ đệm rườm rà, cô đọng câu ngắn gọn & rõ ý"
        case .custom:
            return "Tự định nghĩa quy tắc System Prompt riêng của bạn"
        }
    }

    public var defaultPrompt: String {
        switch self {
        case .standard:
            return "Khôi phục dấu tiếng Việt bị thiếu, sửa lỗi gõ sai chính tả theo đúng ngữ cảnh câu (ví dụ: 'to đang' -> 'Tôi đang', 'không cau' -> 'không dấu', 'thaat sư' -> 'thật sự'). Giữ nguyên trật tự từ và các thuật ngữ tiếng Anh thông dụng."
        case .formalEmail:
            return "Chuẩn hóa câu theo văn phong công sở và email trang trọng, lịch sự. Tuyệt đối không dùng từ viết tắt hay teencode (ko, đc, mn, mik, vs, ntn), sửa triệt để lỗi chính tả, thêm đầy đủ dấu tiếng Việt và dùng đại từ xưng hô lịch sự."
        case .developerIT:
            return "Khôi phục dấu tiếng Việt và sửa lỗi gõ phím nhưng bảo toàn tuyệt đối 100% thuật ngữ lập trình, câu lệnh CLI, tên biến và từ khóa tiếng Anh (API, SDK, build, release, commit, branch, UI, UX, text, suggest, value, model, bug, fix)."
        case .concise:
            return "Sửa lỗi chính tả, khôi phục dấu tiếng Việt và rút gọn câu văn thật súc tích, lược bỏ toàn bộ từ đệm rườm rà (kiểu như là, nói chung là, à ừm, ở thời điểm hiện tại) nhưng giữ nguyên ý cốt lõi."
        case .custom:
            return "Khôi phục dấu tiếng Việt bị thiếu, sửa lỗi gõ sai chính tả theo đúng ngữ cảnh câu và tuân thủ nghiêm ngặt quy tắc văn phong người dùng yêu cầu."
        }
    }
}

/// Result returned by the Apple On-Device Neural Engine (`FoundationModels` / `/usr/bin/fm` + `NaturalLanguage` + `NSSpellChecker`).
public struct OnDeviceAIResult: Equatable, Sendable {
    public let polishedSentence: String
    public let nextWord: String
    public let severity: SuggestionSeverity

    public init(
        polishedSentence: String,
        nextWord: String,
        severity: SuggestionSeverity = .normal
    ) {
        self.polishedSentence = polishedSentence
        self.nextWord = nextWord
        self.severity = severity
    }
}

/// Real-time telemetry snapshot for the Apple On-Device Neural Engine pipeline.
public struct OnDeviceAITelemetry: Equatable, Sendable {
    public let isFoundationModelAvailable: Bool
    public let isFMCLIAvailable: Bool
    public let isFMCLIEnabled: Bool
    public let isNeuralPolishEnabled: Bool
    public let cachedEntries: Int
    public let maxCacheEntries: Int
    public let totalInferences: Int
    public let lastLatencyMs: Double

    public init(
        isFoundationModelAvailable: Bool,
        isFMCLIAvailable: Bool = false,
        isFMCLIEnabled: Bool = false,
        isNeuralPolishEnabled: Bool,
        cachedEntries: Int,
        maxCacheEntries: Int,
        totalInferences: Int,
        lastLatencyMs: Double
    ) {
        self.isFoundationModelAvailable = isFoundationModelAvailable
        self.isFMCLIAvailable = isFMCLIAvailable
        self.isFMCLIEnabled = isFMCLIEnabled
        self.isNeuralPolishEnabled = isNeuralPolishEnabled
        self.cachedEntries = cachedEntries
        self.maxCacheEntries = maxCacheEntries
        self.totalInferences = totalInferences
        self.lastLatencyMs = lastLatencyMs
    }
}

/// Apple On-Device AI Engine combining:
/// 1. Synchronous `<1ms` predictive word completions via `NSSpellChecker` & `NaturalLanguage` (`NLLanguageRecognizer`).
/// 2. Asynchronous Neural Engine LLM inference via Apple `FoundationModels` (`SystemLanguageModel`) or optional macOS 27 `/usr/bin/fm` CLI.
public actor OnDeviceAIEngine {
    public static let shared = OnDeviceAIEngine()

    /// User-controlled toggle in Control Center to enable/disable background FoundationModels Neural Polish.
    public nonisolated(unsafe) static var isNeuralPolishEnabled: Bool = true

    /// Optional toggle to use `/usr/bin/fm` (macOS 27 Apple Foundation Models CLI) when available on the host Mac.
    public nonisolated(unsafe) static var useFMCLIEngine: Bool = false

    /// Active System Prompt preset selected by the user.
    public nonisolated(unsafe) static var activeSystemPromptPreset: SystemPromptPreset = .standard

    /// User-customizable System Prompt instructions guiding sentence suggestions and severity evaluation.
    public nonisolated(unsafe) static var customSystemPrompt: String = SystemPromptPreset.standard.defaultPrompt

    private var cache: [String: OnDeviceAIResult] = [:]
    private let maxCacheEntries = 128
    private var totalInferencesCount: Int = 0
    private var lastInferenceLatencyMs: Double = 0.0

    private static let baseSystemGuardrails = """
    You are an expert Vietnamese and English keyboard input & typo corrector.
    1. Restore missing Vietnamese tone marks and diacritics on unsigned words (e.g. "toi dang thu go tieng viet khong dau" -> "Tôi đang thử gõ tiếng Việt không dấu").
    2. Fix character-level Vietnamese typing and spelling errors according to sentence meaning and context (e.g. "to đang thu go tieng viet không cau" -> "Tôi đang thử gõ tiếng Việt không dấu", "thaat sư không tốt lắm" -> "thật sự không tốt lắm").
    3. Insert at most one missing bridge word if the Vietnamese grammar requires it.
    4. Never expand "go" into "Google" (in Vietnamese "go" is "gõ"). Preserve word order and keep English technical terms (text, suggest, value, model, AI, app, code, bug, user, UI) in English.
    """

    /// Builds the combined system instructions incorporating the user's active System Prompt.
    public nonisolated static var effectiveSystemInstructions: String {
        let userRule = customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userRule.isEmpty else { return baseSystemGuardrails }
        return """
        \(baseSystemGuardrails)
        5. USER SYSTEM PROMPT RULE (STRICT COMPLIANCE): \(userRule)
        """
    }

    public init() {}

    /// Returns true if the macOS 27 `/usr/bin/fm` CLI binary is installed and executable on this Mac.
    public nonisolated static var isFMCLIAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/bin/fm")
    }

    /// Returns true if Apple On-Device Foundation Models (`SystemLanguageModel` or `/usr/bin/fm`) is available on this Mac.
    public nonisolated static var isFoundationModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return isFMCLIAvailable
    }

    /// Counts tokens in the given text using `/usr/bin/fm count-tokens` if available and enabled, or fast local heuristic fallback.
    public nonisolated static func estimateTokenCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return max(1, Int(ceil(Double(words.count) * 1.35)))
    }

    /// Queries `/usr/bin/fm count-tokens` asynchronously when available on macOS 27.
    public func countTokensViaFMCLI(_ text: String) async -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard Self.isFMCLIAvailable else {
            return Self.estimateTokenCount(for: trimmed)
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/fm")
                proc.arguments = ["count-tokens", trimmed]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let out = String(data: data, encoding: .utf8) {
                        let digits = out.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        if let parsed = Int(digits), parsed > 0 {
                            continuation.resume(returning: parsed)
                            return
                        }
                    }
                } catch {}
                continuation.resume(returning: Self.estimateTokenCount(for: trimmed))
            }
        }
    }

    /// Prewarms the Apple Neural Engine language model session on startup to minimize first-token latency.
    public func prewarm() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), Self.isFoundationModelAvailable {
            let session = LanguageModelSession(instructions: Self.effectiveSystemInstructions)
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

    /// Runs on-device Neural Engine LLM inference (`FoundationModels` or optional `/usr/bin/fm` CLI)
    /// to restore diacritics, enforce System Prompt rules, evaluate severity, and predict the next contextual word.
    public func inferSentencePolishAndNextWord(
        rawSentence: String,
        tone: PolishTone = .natural
    ) async -> OnDeviceAIResult? {
        guard Self.isNeuralPolishEnabled else { return nil }
        let trimmed = rawSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        guard wordCount >= 2 && wordCount <= 16 else { return nil }

        let effectiveTone: PolishTone = {
            switch Self.activeSystemPromptPreset {
            case .formalEmail: return .polite
            case .concise: return .concise
            default: return tone
            }
        }()

        // First pass: fast deterministic rule-based polisher + severity evaluator
        let basePolished = VietnameseTextPolisher.polish(trimmed, tone: effectiveTone)
        let heuristicSeverity = SuggestionEngine.evaluateSeverity(
            rawSentence: trimmed,
            polishedSentence: basePolished,
            tone: effectiveTone,
            preset: Self.activeSystemPromptPreset,
            customPrompt: Self.customSystemPrompt
        )

        let promptHash = Self.customSystemPrompt.hashValue
        let cacheKey = "\(effectiveTone.rawValue)|\(Self.useFMCLIEngine)|\(promptHash)|\(basePolished.lowercased())"
        if let cached = cache[cacheKey] {
            return cached
        }

        // Path A: Optional macOS 27 `/usr/bin/fm` CLI Engine when enabled by user and available on system
        if Self.useFMCLIEngine && Self.isFMCLIAvailable {
            let startClock = CFAbsoluteTimeGetCurrent()
            if let fmResult = await invokeFMCLI(
                rawInput: trimmed,
                basePolished: basePolished,
                tone: effectiveTone,
                heuristicSeverity: heuristicSeverity
            ) {
                let elapsedMs = max(1.0, (CFAbsoluteTimeGetCurrent() - startClock) * 1000.0)
                lastInferenceLatencyMs = elapsedMs
                totalInferencesCount += 1
                storeCache(key: cacheKey, value: fmResult)
                return fmResult
            }
        }

        // Path B: Native Apple FoundationModels framework
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), Self.isFoundationModelAvailable {
            do {
                let startClock = CFAbsoluteTimeGetCurrent()
                let session = LanguageModelSession(instructions: Self.effectiveSystemInstructions)
                let options = GenerationOptions(samplingMode: .greedy)
                let response = try await session.respond(
                    to: "Correct Vietnamese typos, restore missing diacritics, and follow System Prompt for: \(basePolished)",
                    generating: OnDeviceAISuggestions.self,
                    options: options
                )
                let elapsedMs = max(1.0, (CFAbsoluteTimeGetCurrent() - startClock) * 1000.0)
                lastInferenceLatencyMs = elapsedMs
                totalInferencesCount += 1

                let validatedPolished = postProcessCandidate(
                    rawInput: trimmed,
                    basePolished: basePolished,
                    llmCandidate: response.content.polishedSentence,
                    tone: effectiveTone
                )

                let cleanNext = response.content.nextWord
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .punctuationCharacters)

                let llmSeverity = SuggestionSeverity(rawValue: max(0, min(2, response.content.severityLevel))) ?? .normal
                let finalSeverity = max(heuristicSeverity, llmSeverity)

                let res = OnDeviceAIResult(
                    polishedSentence: validatedPolished,
                    nextWord: cleanNext,
                    severity: finalSeverity
                )
                storeCache(key: cacheKey, value: res)
                return res
            } catch {
                return OnDeviceAIResult(
                    polishedSentence: basePolished,
                    nextWord: "",
                    severity: heuristicSeverity
                )
            }
        }
        #endif
        return OnDeviceAIResult(
            polishedSentence: basePolished,
            nextWord: "",
            severity: heuristicSeverity
        )
    }

    private func postProcessCandidate(
        rawInput: String,
        basePolished: String,
        llmCandidate: String,
        tone: PolishTone
    ) -> String {
        var candidate = llmCandidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "bộ Go", with: "bộ gõ")
            .replacingOccurrences(of: "thử Google", with: "thử gõ")
            .replacingOccurrences(of: "Google tiếng Việt", with: "gõ tiếng Việt")

        candidate = VietnameseTextPolisher.polish(candidate, tone: tone)

        if !rawInput.hasSuffix(".") && candidate.hasSuffix(".") {
            candidate.removeLast()
        }

        if Self.isValidRefinement(base: basePolished, candidate: candidate) {
            return candidate
        }
        return basePolished
    }

    /// Invokes `/usr/bin/fm respond` with structured JSON schema and `--guardrails permissive-content-transformations`.
    private func invokeFMCLI(
        rawInput: String,
        basePolished: String,
        tone: PolishTone,
        heuristicSeverity: SuggestionSeverity
    ) async -> OnDeviceAIResult? {
        let instructions = Self.effectiveSystemInstructions
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let schemaJSON = """
                {
                  "additionalProperties" : false,
                  "type" : "object",
                  "properties" : {
                    "polishedSentence" : {
                      "type" : "string",
                      "description" : "Câu tiếng Việt đã sửa lỗi chính tả, thêm dấu và chuẩn hóa theo System Prompt"
                    },
                    "nextWord" : {
                      "type" : "string",
                      "description" : "1 hoặc 2 từ gợi ý tiếp theo"
                    },
                    "severityLevel" : {
                      "type" : "integer",
                      "description" : "0=chuẩn, 1=cần sửa nhẹ, 2=sai chính tả nặng hoặc lệch chuẩn System Prompt"
                    }
                  },
                  "title" : "VFlowSuggestion",
                  "required" : ["polishedSentence", "nextWord", "severityLevel"],
                  "x-order" : ["polishedSentence", "nextWord", "severityLevel"]
                }
                """

                let schemaURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vflow_fm_schema.json")
                try? schemaJSON.write(to: schemaURL, atomically: true, encoding: .utf8)

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/fm")
                proc.arguments = [
                    "respond",
                    "-g",
                    "--no-stream",
                    "--guardrails", "permissive-content-transformations",
                    "-i", instructions,
                    "--schema", schemaURL.path,
                    "Sửa lỗi chính tả, khôi phục dấu tiếng Việt và chuẩn hóa theo System Prompt: \(basePolished)"
                ]
                let outPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = Pipe()

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    guard proc.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let rawPolished = json["polishedSentence"] as? String {
                        let nextW = (json["nextWord"] as? String ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: .punctuationCharacters)
                        let rawSev = (json["severityLevel"] as? Int) ?? heuristicSeverity.rawValue
                        let llmSeverity = SuggestionSeverity(rawValue: max(0, min(2, rawSev))) ?? .normal
                        let finalSeverity = max(heuristicSeverity, llmSeverity)

                        var candidate = rawPolished
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "bộ Go", with: "bộ gõ")
                            .replacingOccurrences(of: "thử Google", with: "thử gõ")
                            .replacingOccurrences(of: "Google tiếng Việt", with: "gõ tiếng Việt")
                        candidate = VietnameseTextPolisher.polish(candidate, tone: tone)
                        if !rawInput.hasSuffix(".") && candidate.hasSuffix(".") {
                            candidate.removeLast()
                        }
                        let validated = Self.isValidRefinement(base: basePolished, candidate: candidate) ? candidate : basePolished
                        continuation.resume(
                            returning: OnDeviceAIResult(
                                polishedSentence: validated,
                                nextWord: nextW,
                                severity: finalSeverity
                            )
                        )
                        return
                    }
                } catch {}
                continuation.resume(returning: nil)
            }
        }
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
            isFMCLIAvailable: Self.isFMCLIAvailable,
            isFMCLIEnabled: Self.useFMCLIEngine && Self.isFMCLIAvailable,
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
