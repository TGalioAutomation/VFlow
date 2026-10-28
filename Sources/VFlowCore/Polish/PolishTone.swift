import Foundation

/// Supported tones/styles for Vietnamese text polishing.
public enum PolishTone: String, Codable, CaseIterable, Sendable {
    case natural
    case polite
    case concise

    public var displayName: String {
        switch self {
        case .natural:
            return "Tự nhiên"
        case .polite:
            return "Lịch sự"
        case .concise:
            return "Ngắn gọn"
        }
    }

    public var badgeIcon: String {
        switch self {
        case .natural:
            return "leaf.fill"
        case .polite:
            return "tie.fill"
        case .concise:
            return "bolt.fill"
        }
    }
}
