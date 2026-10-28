import Foundation

/// Detects autocomplete fields (e.g. browser URL bars, Spotlight, Raycast) to prevent key swallowing.
public struct AutocompleteDetector: Sendable {
    public static let launcherBundleIds: Set<String> = [
        "com.apple.Spotlight",
        "com.raycast.macos",
        "com.runningwithcrayons.Alfred",
        "com.solwork.sol"
    ]

    public static let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.mozilla.firefox"
    ]

    /// Determines if the current context represents an autocomplete search or URL field.
    public static func isAutocompleteField(
        bundleId: String?,
        role: String? = nil,
        subrole: String? = nil
    ) -> Bool {
        guard let bundleId = bundleId else { return false }

        // 1. System launchers are always autocomplete fields
        if launcherBundleIds.contains(bundleId) {
            return true
        }

        // 2. Browsers with search/URL field subroles
        if browserBundleIds.contains(bundleId) {
            if let sub = subrole, sub.contains("AXSearchField") || sub.contains("AXURL") {
                return true
            }
        }

        return false
    }
}
