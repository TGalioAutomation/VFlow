import Foundation

/// Fast offline rule-based implementation of LocalLLMProvider (<5ms latency).
public final class RuleBasedLLMStub: LocalLLMProvider, Sendable {
    public init() {}

    public func polishText(input: String, tone: PolishTone) async throws -> String {
        VietnameseTextPolisher.polish(input, tone: tone)
    }
}
