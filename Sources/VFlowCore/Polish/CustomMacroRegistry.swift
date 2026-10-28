import Foundation

/// Validation error when creating or updating a custom shorthand macro.
public enum MacroValidationError: LocalizedError, Equatable, Sendable {
    case emptyTrigger
    case triggerContainsWhitespace
    case triggerTooLong
    case emptyReplacement
    case identicalTriggerAndReplacement

    public var errorDescription: String? {
        switch self {
        case .emptyTrigger:
            return "Từ viết tắt không được để trống."
        case .triggerContainsWhitespace:
            return "Từ viết tắt chỉ gồm 1 từ liền nhau (không chứa khoảng trắng)."
        case .triggerTooLong:
            return "Từ viết tắt tối đa 24 ký tự."
        case .emptyReplacement:
            return "Nội dung thay thế không được để trống."
        case .identicalTriggerAndReplacement:
            return "Từ viết tắt và nội dung thay thế không được giống hệt nhau."
        }
    }
}

/// A single shorthand macro entry managed in the VFlow Control Center.
public struct CustomMacroItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { trigger.lowercased() }
    public var trigger: String
    public var replacement: String
    public var isEnabled: Bool
    public var isBuiltIn: Bool

    public init(
        trigger: String,
        replacement: String,
        isEnabled: Bool = true,
        isBuiltIn: Bool = false
    ) {
        self.trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.replacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }
}

/// Thread-safe registry for user-customizable shorthand macros backed by `UserDefaults`.
public final class CustomMacroRegistry: @unchecked Sendable {
    public static let shared = CustomMacroRegistry()

    private let storageKey = "vflow.customMacros.v1"
    private let expandOnSpaceKey = "vflow.expandMacrosOnSpace.v1"
    private let lock = NSLock()
    private var items: [CustomMacroItem] = []

    /// Default curated Vietnamese & bilingual shorthands.
    public static let defaultItems: [CustomMacroItem] = [
        CustomMacroItem(trigger: "dc", replacement: "được", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "ko", replacement: "không", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "ntn", replacement: "như thế nào", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "mn", replacement: "mọi người", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "trc", replacement: "trước", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "vn", replacement: "Việt Nam", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "tks", replacement: "cảm ơn bạn", isEnabled: true, isBuiltIn: true),
        CustomMacroItem(trigger: "kocg", replacement: "không có gì", isEnabled: true, isBuiltIn: true)
    ]

    public var expandMacrosOnSpace: Bool {
        get {
            lock.withLock {
                if UserDefaults.standard.object(forKey: expandOnSpaceKey) == nil {
                    return true
                }
                return UserDefaults.standard.bool(forKey: expandOnSpaceKey)
            }
        }
        set {
            lock.withLock {
                UserDefaults.standard.set(newValue, forKey: expandOnSpaceKey)
            }
        }
    }

    public init() {
        loadFromDefaults()
    }

    /// Returns all registered macro items in display order.
    public func allItems() -> [CustomMacroItem] {
        lock.withLock { items }
    }

    /// Returns a dictionary of lowercase trigger -> replacement for all enabled macros.
    public func activeMapping() -> [String: String] {
        lock.withLock {
            var map: [String: String] = [:]
            for item in items where item.isEnabled {
                map[item.trigger.lowercased()] = item.replacement
            }
            return map
        }
    }

    /// Looks up an active replacement for a given word or raw buffer.
    public func lookup(_ word: String) -> String? {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return lock.withLock {
            items.first(where: { $0.isEnabled && $0.trigger == key })?.replacement
        }
    }

    /// Validates a macro trigger and replacement before saving.
    public static func validate(trigger: String, replacement: String) -> MacroValidationError? {
        let cleanTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanTrigger.isEmpty {
            return .emptyTrigger
        }
        if cleanTrigger.contains(where: { $0.isWhitespace }) {
            return .triggerContainsWhitespace
        }
        if cleanTrigger.count > 24 {
            return .triggerTooLong
        }
        if cleanReplacement.isEmpty {
            return .emptyReplacement
        }
        if cleanTrigger == cleanReplacement.lowercased() {
            return .identicalTriggerAndReplacement
        }
        return nil
    }

    /// Adds a new macro or updates an existing macro with the same trigger.
    @discardableResult
    public func addOrUpdate(trigger: String, replacement: String) -> Result<CustomMacroItem, MacroValidationError> {
        if let error = Self.validate(trigger: trigger, replacement: replacement) {
            return .failure(error)
        }
        let cleanTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        return lock.withLock {
            if let idx = items.firstIndex(where: { $0.trigger == cleanTrigger }) {
                items[idx].replacement = cleanReplacement
                items[idx].isEnabled = true
                saveToDefaultsLocked()
                return .success(items[idx])
            } else {
                let newItem = CustomMacroItem(
                    trigger: cleanTrigger,
                    replacement: cleanReplacement,
                    isEnabled: true,
                    isBuiltIn: false
                )
                items.insert(newItem, at: 0)
                saveToDefaultsLocked()
                return .success(newItem)
            }
        }
    }

    /// Toggles the enabled state of a macro by ID.
    public func toggle(id: String) {
        let lowerId = id.lowercased()
        lock.withLock {
            guard let idx = items.firstIndex(where: { $0.id == lowerId }) else { return }
            items[idx].isEnabled.toggle()
            saveToDefaultsLocked()
        }
    }

    /// Removes a macro by ID.
    public func remove(id: String) {
        let lowerId = id.lowercased()
        lock.withLock {
            items.removeAll { $0.id == lowerId }
            saveToDefaultsLocked()
        }
    }

    /// Resets macros back to the default curated list.
    public func resetToDefaults() {
        lock.withLock {
            items = Self.defaultItems
            saveToDefaultsLocked()
        }
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        lock.withLock {
            if let data = UserDefaults.standard.data(forKey: storageKey),
               let decoded = try? JSONDecoder().decode([CustomMacroItem].self, from: data),
               !decoded.isEmpty {
                items = decoded
            } else {
                items = Self.defaultItems
            }
        }
    }

    private func saveToDefaultsLocked() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
