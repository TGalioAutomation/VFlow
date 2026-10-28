import Foundation

/// Buffers the current typing context (words/sentences) to enable mouse-free sentence polishing and undo.
public final class TypingBuffer: @unchecked Sendable {
    public static let shared = TypingBuffer()

    private var words: [String] = []
    private var undoHistory: [String] = []
    private let maxWords = 500
    private let lock = NSLock()

    public init() {}

    /// Appends a newly finished word to the sentence buffer.
    public func appendWord(_ word: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        words.append(clean)
        if words.count > maxWords {
            words.removeFirst()
        }
    }

    /// Attaches a punctuation character (e.g. `.`, `,`, `!`, `?`, `;`, `:`) to the last completed word in the buffer
    /// so sentences separated by `.` are preserved without breaking or losing context.
    public func appendPunctuation(_ punct: Character) {
        lock.lock()
        defer { lock.unlock() }
        guard !words.isEmpty else { return }
        let last = words[words.count - 1]
        if !last.hasSuffix(String(punct)) {
            words[words.count - 1] = last + String(punct)
        }
    }

    /// Returns the current active sentence buffer as a single joined string.
    public func currentSentence() -> String {
        lock.lock()
        defer { lock.unlock() }
        return words.joined(separator: " ")
    }

    /// Returns the list of words in the current typing buffer.
    public func recentWords() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return words
    }

    /// Removes 1 character from the last completed word (or drops the word when empty) when user presses Backspace across a word boundary.
    public func popLastWord() {
        lock.lock()
        defer { lock.unlock() }
        guard let last = words.last else { return }
        if last.count <= 1 {
            _ = words.popLast()
        } else {
            words[words.count - 1] = String(last.dropLast())
        }
    }

    /// Replaces the last completed word in the buffer.
    public func replaceLastWord(with newWord: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if !words.isEmpty {
            words[words.count - 1] = clean
        } else {
            words.append(clean)
        }
    }

    /// Synchronizes the typing buffer with the actual live text from the focused UI element,
    /// preserving the entire input box across sentences (`.`, `!`, `?`) and paragraphs (`\n`) up to `maxWords`.
    public func syncWithLiveText(_ liveText: String, currentComposingWord: String) {
        lock.lock()
        defer { lock.unlock() }

        let trimmed = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            words.removeAll()
            return
        }

        var tokens = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // If user is currently composing the last word (no trailing space), drop the in-progress token from completed words
        let cleanComposing = currentComposingWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanComposing.isEmpty, let lastTok = tokens.last,
           lastTok.lowercased() == cleanComposing.lowercased() && !liveText.hasSuffix(" ") {
            tokens.removeLast()
        }

        words = Array(tokens.suffix(maxWords))
    }

    /// Records current text before applying a polish transformation so it can be undone via ⌘Z.
    public func recordForUndo(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        undoHistory.append(text)
        if undoHistory.count > 10 {
            undoHistory.removeFirst()
        }
    }

    /// Pops the previous sentence state for undo.
    public func popUndo() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return undoHistory.popLast()
    }

    /// Clears the typing buffer.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        words.removeAll()
    }
}
