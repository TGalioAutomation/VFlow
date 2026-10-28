import Foundation

/// Protocol for local on-device AI text polishing engines.
public protocol LocalLLMProvider: Sendable {
    /// Polishes input text to the specified tone.
    func polishText(input: String, tone: PolishTone) async throws -> String
}
