import Foundation

/// Method used for Vietnamese input processing.
public enum InputMethod: String, Codable, CaseIterable, Sendable {
    case telex
    case vni
    case off

    public var displayName: String {
        switch self {
        case .telex:
            return "Telex"
        case .vni:
            return "VNI"
        case .off:
            return "Tắt (English)"
        }
    }

    public var shortBadge: String {
        switch self {
        case .telex:
            return "VI Telex"
        case .vni:
            return "VI VNI"
        case .off:
            return "EN"
        }
    }
}
