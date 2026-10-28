import Foundation

/// Remembers and switches input modes based on the active application's bundle identifier.
public final class PerAppStateManager: @unchecked Sendable {
    public static let shared = PerAppStateManager()

    private var appModes: [String: InputMethod] = [:]
    public var defaultMethod: InputMethod = .telex
    private let lock = NSLock()

    public init() {
        // Sensible defaults for coding / terminal apps
        appModes["com.apple.Terminal"] = .off
        appModes["com.googlecode.iterm2"] = .off
        appModes["dev.warp.Warp-Stable"] = .off
        appModes["com.todesktop.230313mzl4w4u92"] = .telex // Cursor
        appModes["com.microsoft.VSCode"] = .telex
    }

    /// Gets the input method configured for the given bundle identifier.
    public func mode(for bundleId: String?) -> InputMethod {
        guard let bundleId = bundleId, !bundleId.isEmpty else {
            return defaultMethod
        }
        lock.lock()
        defer { lock.unlock() }
        return appModes[bundleId] ?? defaultMethod
    }

    /// Sets the input method for a specific bundle identifier.
    public func setMode(_ mode: InputMethod, for bundleId: String) {
        lock.lock()
        defer { lock.unlock() }
        appModes[bundleId] = mode
    }
}
