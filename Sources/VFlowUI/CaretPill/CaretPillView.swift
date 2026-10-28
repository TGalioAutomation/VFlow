import SwiftUI
import VFlowCore

/// The Caret Pill HUD View implementing Prototype v8 — Clean Minimal Wave + Real-Time Suggestions + 3-Level Severity Color Coding.
public struct CaretPillView: View {
    @Binding public var state: CaretPillState
    @Binding public var text: String
    @Binding public var audioLevel: Float
    @Binding public var currentTone: PolishTone

    public var currentWord: String
    public var suggestions: [SuggestionItem]
    public var inputMethod: InputMethod
    public var severity: SuggestionSeverity
    public var acceptShortcut: SuggestionAcceptShortcut
    public var isDoubleTabArmed: Bool
    public var isApplyingSuggestion: Bool
    public var isSuggestionAppliedSuccess: Bool
    public var appliedSuggestionText: String
    public var onUndo: () -> Void
    public var onCycleTone: () -> Void
    public var onSelectSuggestion: (SuggestionItem) -> Void
    public var onToggleInputMethod: () -> Void
    public var onUpdateChipFrame: ((Int, CGRect) -> Void)?
    public var onUpdateModeButtonFrame: ((CGRect) -> Void)?
    public var onUpdateUndoButtonFrame: ((CGRect) -> Void)?
    public var onUpdateToneButtonFrame: ((CGRect) -> Void)?

    public init(
        state: Binding<CaretPillState>,
        text: Binding<String>,
        audioLevel: Binding<Float>,
        currentTone: Binding<PolishTone>,
        currentWord: String = "",
        suggestions: [SuggestionItem] = [],
        inputMethod: InputMethod = .telex,
        severity: SuggestionSeverity = .normal,
        acceptShortcut: SuggestionAcceptShortcut = .doubleTab,
        isDoubleTabArmed: Bool = false,
        isApplyingSuggestion: Bool = false,
        isSuggestionAppliedSuccess: Bool = false,
        appliedSuggestionText: String = "",
        onUndo: @escaping () -> Void = {},
        onCycleTone: @escaping () -> Void = {},
        onSelectSuggestion: @escaping (SuggestionItem) -> Void = { _ in },
        onToggleInputMethod: @escaping () -> Void = {},
        onUpdateChipFrame: ((Int, CGRect) -> Void)? = nil,
        onUpdateModeButtonFrame: ((CGRect) -> Void)? = nil,
        onUpdateUndoButtonFrame: ((CGRect) -> Void)? = nil,
        onUpdateToneButtonFrame: ((CGRect) -> Void)? = nil
    ) {
        self._state = state
        self._text = text
        self._audioLevel = audioLevel
        self._currentTone = currentTone
        self.currentWord = currentWord
        self.suggestions = suggestions
        self.inputMethod = inputMethod
        self.severity = severity
        self.acceptShortcut = acceptShortcut
        self.isDoubleTabArmed = isDoubleTabArmed
        self.isApplyingSuggestion = isApplyingSuggestion
        self.isSuggestionAppliedSuccess = isSuggestionAppliedSuccess
        self.appliedSuggestionText = appliedSuggestionText
        self.onUndo = onUndo
        self.onCycleTone = onCycleTone
        self.onSelectSuggestion = onSelectSuggestion
        self.onToggleInputMethod = onToggleInputMethod
        self.onUpdateChipFrame = onUpdateChipFrame
        self.onUpdateModeButtonFrame = onUpdateModeButtonFrame
        self.onUpdateUndoButtonFrame = onUpdateUndoButtonFrame
        self.onUpdateToneButtonFrame = onUpdateToneButtonFrame
    }

    private var effectiveSeverity: SuggestionSeverity {
        let maxItemSev = suggestions.map(\.severity).max() ?? .normal
        return max(severity, maxItemSev)
    }

    private func accentColor(for level: SuggestionSeverity) -> Color {
        switch level {
        case .normal:
            return Color(red: 56/255, green: 189/255, blue: 248/255) // Cyan #38BDF8
        case .moderate:
            return Color(red: 251/255, green: 191/255, blue: 36/255) // Amber #FBBF24
        case .high:
            return Color(red: 251/255, green: 113/255, blue: 133/255) // Rose #FB7185
        }
    }

    public var isLongCardMode: Bool {
        if isApplyingSuggestion || isSuggestionAppliedSuccess {
            return false
        }
        if let first = visibleSuggestions.first,
           first.kind == .aiPolish,
           (first.text.count > 56 || first.text.contains("\n")) {
            return true
        }
        return false
    }

    public var body: some View {
        let pillAccent: Color = {
            if isApplyingSuggestion {
                return Color(red: 168/255, green: 85/255, blue: 247/255) // AI Violet #A855F7
            }
            if isSuggestionAppliedSuccess {
                return Color(red: 52/255, green: 211/255, blue: 153/255) // Emerald #34D399
            }
            return accentColor(for: effectiveSeverity)
        }()
        let isHighlightedFrame = isApplyingSuggestion || isSuggestionAppliedSuccess || isDoubleTabArmed || effectiveSeverity != .normal

        Group {
            if isLongCardMode, let first = visibleSuggestions.first {
                longCardBody(item: first, pillAccent: pillAccent)
            } else {
                compactPillBody(pillAccent: pillAccent)
            }
        }
        .background(
            // Deep Obsidian (#0D1324) 96% + Rounded UltraThin blur (no rectangular corner bleed)
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: isLongCardMode ? 18 : 20)
                Color(red: 13/255, green: 19/255, blue: 36/255).opacity(0.95)
            }
            .clipShape(RoundedRectangle(cornerRadius: isLongCardMode ? 18 : 20, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: isLongCardMode ? 18 : 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isLongCardMode ? 18 : 20, style: .continuous)
                .stroke(
                    pillAccent.opacity(isHighlightedFrame ? 0.82 : 0.35),
                    lineWidth: isHighlightedFrame ? 1.55 : 1.0
                )
        )
        .shadow(
            color: isHighlightedFrame ? pillAccent.opacity(0.36) : Color.black.opacity(0.35),
            radius: isHighlightedFrame ? 12 : 8,
            x: 0,
            y: 4
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isApplyingSuggestion)
        .animation(.spring(response: 0.26, dampingFraction: 0.80), value: isSuggestionAppliedSuccess)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isDoubleTabArmed)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .coordinateSpace(name: "CaretPillRoot")
    }

    @ViewBuilder
    private func compactPillBody(pillAccent: Color) -> some View {
        HStack(spacing: 8) {
            // Block 1: Left 52x22px Silk Sine-Wave + VI/EN Mode Badge
            SilkSineWaveView(
                state: state,
                audioLevel: audioLevel,
                severity: effectiveSeverity
            )
            .padding(.leading, 8)

            modeToggleButton(pillAccent: pillAccent)

            // Block 2: Center Interactive Suggestions, Rewrite Animation, or Live Text Area
            if isApplyingSuggestion {
                HStack(spacing: 6) {
                    Text("✨ Đang sửa văn bản...")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 216/255, green: 180/255, blue: 254/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.26))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 192/255, green: 132/255, blue: 252/255).opacity(0.65), lineWidth: 0.9)
                        )

                    if !appliedSuggestionText.isEmpty {
                        Text(appliedSuggestionText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 241/255, green: 245/255, blue: 249/255))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 320, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            } else if isSuggestionAppliedSuccess {
                HStack(spacing: 6) {
                    Text("✓ Đã sửa văn bản")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 110/255, green: 231/255, blue: 183/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.24))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 52/255, green: 211/255, blue: 153/255).opacity(0.65), lineWidth: 0.9)
                        )

                    if !appliedSuggestionText.isEmpty {
                        Text(appliedSuggestionText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 226/255, green: 232/255, blue: 240/255))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 320, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            } else if !visibleSuggestions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(visibleSuggestions.enumerated()), id: \.offset) { index, item in
                        suggestionChip(item: item, index: index)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            } else {
                Text(displayContent)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundColor(Color(red: 241/255, green: 245/255, blue: 249/255))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.4), value: text)
            }

            // Block 3: Right Divider and Status / Actions
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 18)

            rightSection
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 10)
        }
        .frame(minHeight: 40)
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private func longCardBody(item: SuggestionItem, pillAccent: Color) -> some View {
        let chipSeverity = max(item.severity, effectiveSeverity)
        let chipColor: Color = {
            if chipSeverity == .high { return accentColor(for: .high) }
            if chipSeverity == .moderate { return accentColor(for: .moderate) }
            return Color(red: 168/255, green: 85/255, blue: 247/255)
        }()
        let changedCount = Self.countChangedWords(raw: text, polished: item.text)
        let estLines = Self.estimatedLineCount(for: item.text)

        VStack(alignment: .leading, spacing: 6) {
            // Tier 1: Top Header Bar (Silk Wave + VI·AI + Shortcut Header Pill + Undo/Tone Controls)
            HStack(spacing: 8) {
                SilkSineWaveView(
                    state: state,
                    audioLevel: audioLevel,
                    severity: effectiveSeverity
                )

                modeToggleButton(pillAccent: pillAccent)

                Button(action: { onSelectSuggestion(item) }) {
                    HStack(spacing: 5) {
                        Text(isDoubleTabArmed ? "⇥ Nhấn Tab lần nữa" : acceptShortcut.shortBadge)
                            .font(.system(size: 10, weight: .bold, design: isDoubleTabArmed ? .rounded : .monospaced))
                            .foregroundColor(isDoubleTabArmed ? Color.white : chipColor)
                            .padding(.horizontal, isDoubleTabArmed ? 6 : 2)
                            .padding(.vertical, 1)
                            .background(isDoubleTabArmed ? chipColor.opacity(0.92) : chipColor.opacity(0.16))
                            .clipShape(Capsule())

                        Text(changedCount > 0
                             ? "✨ Gợi ý sửa toàn văn bản (\(changedCount) vị trí)"
                             : "✨ Gợi ý sửa toàn văn bản")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(chipColor)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(chipColor.opacity(isDoubleTabArmed ? 0.25 : 0.14))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(chipColor.opacity(isDoubleTabArmed ? 0.85 : 0.42), lineWidth: isDoubleTabArmed ? 1.2 : 0.7)
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 18)

                rightSection
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)

            // Tier 2: Full-width Diff-Highlighted Multi-Line Card (up to 4-5 visible lines + smooth vertical scroll)
            Button(action: { onSelectSuggestion(item) }) {
                Group {
                    if estLines >= 5 {
                        ScrollView(.vertical, showsIndicators: true) {
                            Self.highlightedDiffText(
                                raw: text,
                                polished: item.text,
                                baseColor: Color(red: 226/255, green: 232/255, blue: 240/255),
                                highlightColor: chipSeverity == .high
                                    ? Color(red: 253/255, green: 164/255, blue: 175/255)
                                    : Color(red: 253/255, green: 224/255, blue: 71/255)
                            )
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, 4)
                        }
                        .frame(height: 96)
                    } else {
                        Self.highlightedDiffText(
                            raw: text,
                            polished: item.text,
                            baseColor: Color(red: 226/255, green: 232/255, blue: 240/255),
                            highlightColor: chipSeverity == .high
                                ? Color(red: 253/255, green: 164/255, blue: 175/255)
                                : Color(red: 253/255, green: 224/255, blue: 71/255)
                        )
                        .lineSpacing(3)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(chipColor.opacity(chipSeverity == .high ? 0.20 : 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            chipColor.opacity(chipSeverity == .high ? 0.62 : 0.42),
                            lineWidth: isDoubleTabArmed ? 1.4 : 0.85
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("CaretPillRoot"))
                    Color.clear
                        .onAppear { onUpdateChipFrame?(0, frame) }
                        .onChange(of: frame) { _, newFrame in onUpdateChipFrame?(0, newFrame) }
                }
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .help("Click chuột, \(acceptShortcut.shortBadge) hoặc ⌥1 để thay thế toàn bộ văn bản")
        }
        .frame(width: 560)
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private func modeToggleButton(pillAccent: Color) -> some View {
        Button(action: onToggleInputMethod) {
            let modeLabel = inputMethod == .off ? "EN" : "VI"
            let badgeText = OnDeviceAIEngine.isFoundationModelAvailable ? "\(modeLabel)·AI" : modeLabel
            Text(badgeText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(
                    inputMethod == .off
                        ? Color(red: 148/255, green: 163/255, blue: 184/255)
                        : pillAccent
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    (inputMethod == .off ? Color.white.opacity(0.06) : pillAccent.opacity(0.16))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            inputMethod == .off
                                ? Color.white.opacity(0.12)
                                : pillAccent.opacity(0.40),
                            lineWidth: 0.5
                        )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                let frame = geo.frame(in: .named("CaretPillRoot"))
                Color.clear
                    .onAppear { onUpdateModeButtonFrame?(frame) }
                    .onChange(of: frame) { _, newFrame in onUpdateModeButtonFrame?(newFrame) }
            }
        )
        .help("Chuyển nhanh VI ⇄ EN (⌥Z)")
    }

    /// Estimates the number of visual lines needed to render `text` inside the 536px card text area.
    public static func estimatedLineCount(for text: String) -> Int {
        let paragraphs = text.components(separatedBy: "\n")
        var totalLines = 0
        for p in paragraphs {
            let count = max(1, p.count)
            totalLines += max(1, Int(ceil(Double(count) / 64.0)))
        }
        return totalLines
    }

    /// Counts how many words in `polished` differ from `raw` using a sliding lookahead window.
    public static func countChangedWords(raw: String, polished: String) -> Int {
        let rawWords = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let polWords = polished.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !rawWords.isEmpty, !polWords.isEmpty else { return 0 }
        var rawIdx = 0
        var changed = 0
        for word in polWords {
            let upper = min(rawWords.count, rawIdx + 8)
            var matchedAt: Int? = nil
            if rawIdx < upper {
                for k in rawIdx..<upper where rawWords[k] == word {
                    matchedAt = k
                    break
                }
            }
            if let k = matchedAt {
                rawIdx = k + 1
            } else {
                changed += 1
                if rawIdx < rawWords.count {
                    rawIdx += 1
                }
            }
        }
        return changed
    }

    /// Builds a SwiftUI `Text` that highlights repaired/changed tokens in `polished` compared to `raw`.
    public static func highlightedDiffText(
        raw: String,
        polished: String,
        baseColor: Color,
        highlightColor: Color
    ) -> Text {
        let rawWords = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !rawWords.isEmpty else {
            return Text(polished)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(baseColor)
        }

        // Tokenize `polished` into alternating word and whitespace/newline runs so layout & line breaks are 100% preserved
        var segments: [(text: String, isWord: Bool)] = []
        var current = ""
        var currentIsWord: Bool? = nil
        for ch in polished {
            let isWS = ch.isWhitespace || ch.isNewline
            let isWord = !isWS
            if let prev = currentIsWord, prev != isWord {
                segments.append((current, prev))
                current = String(ch)
                currentIsWord = isWord
            } else {
                current.append(ch)
                currentIsWord = isWord
            }
        }
        if let lastIsWord = currentIsWord, !current.isEmpty {
            segments.append((current, lastIsWord))
        }

        var rawIdx = 0
        var attr = AttributedString()
        for seg in segments {
            if !seg.isWord {
                var ws = AttributedString(seg.text)
                ws.font = .system(size: 12.5, weight: .regular)
                ws.foregroundColor = baseColor
                attr.append(ws)
            } else {
                let upper = min(rawWords.count, rawIdx + 8)
                var matchedAt: Int? = nil
                if rawIdx < upper {
                    for k in rawIdx..<upper where rawWords[k] == seg.text {
                        matchedAt = k
                        break
                    }
                }
                var wordAttr = AttributedString(seg.text)
                if let k = matchedAt {
                    rawIdx = k + 1
                    wordAttr.font = .system(size: 12.5, weight: .regular)
                    wordAttr.foregroundColor = baseColor
                } else {
                    if rawIdx < rawWords.count {
                        rawIdx += 1
                    }
                    wordAttr.font = .system(size: 12.5, weight: .bold)
                    wordAttr.foregroundColor = highlightColor
                }
                attr.append(wordAttr)
            }
        }
        return Text(attr)
    }

    private var visibleSuggestions: [SuggestionItem] {
        guard !suggestions.isEmpty else { return [] }
        if let first = suggestions.first, first.kind == .aiPolish, first.text.count > 26 {
            return [first]
        }
        let hasLongPolish = suggestions.prefix(2).contains { $0.kind == .aiPolish && $0.text.count > 12 }
        if hasLongPolish {
            return Array(suggestions.prefix(2))
        }
        return Array(suggestions.prefix(3))
    }

    @ViewBuilder
    private func suggestionChip(item: SuggestionItem, index: Int) -> some View {
        let isHighlight = (index == 0) || item.kind == .teencodeExpansion || item.kind == .aiPolish
        let chipSeverity = max(item.severity, index == 0 ? effectiveSeverity : .normal)
        let chipColor: Color = {
            if chipSeverity == .high && (index == 0 || item.kind == .aiPolish || item.kind == .teencodeExpansion) {
                return accentColor(for: .high)
            }
            if chipSeverity == .moderate && (index == 0 || item.kind == .aiPolish || item.kind == .teencodeExpansion) {
                return accentColor(for: .moderate)
            }
            if item.kind == .aiPolish {
                return Color(red: 168/255, green: 85/255, blue: 247/255)
            }
            return accentColor(for: .normal)
        }()

        Button(action: { onSelectSuggestion(item) }) {
            HStack(spacing: 4) {
                if index == 0 {
                    Text(isDoubleTabArmed ? "⇥ Nhấn Tab lần nữa" : acceptShortcut.shortBadge)
                        .font(.system(size: 10, weight: .bold, design: isDoubleTabArmed ? .rounded : .monospaced))
                        .foregroundColor(isDoubleTabArmed ? Color.white : chipColor)
                        .padding(.horizontal, isDoubleTabArmed ? 6 : 1)
                        .padding(.vertical, isDoubleTabArmed ? 2 : 0)
                        .background(
                            isDoubleTabArmed ? chipColor.opacity(0.92) : Color.clear
                        )
                        .clipShape(Capsule())
                } else {
                    Text("⌥\(index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.65))
                }

                if item.kind == .aiPolish {
                    Text("✨")
                        .font(.system(size: 10))
                } else if item.kind == .teencodeExpansion {
                    Text("⚡")
                        .font(.system(size: 10))
                }

                if item.kind == .aiPolish && item.text.count > 68 {
                    Text(item.text)
                        .font(.system(size: 12.5, weight: isHighlight ? .semibold : .regular))
                        .foregroundColor(Color(red: 241/255, green: 245/255, blue: 249/255))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 640, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(item.text)
                        .font(.system(size: 12.5, weight: isHighlight ? .semibold : .regular))
                        .foregroundColor(Color(red: 241/255, green: 245/255, blue: 249/255))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                isHighlight
                    ? chipColor.opacity(chipSeverity == .high ? 0.28 : 0.22)
                    : Color.white.opacity(0.07)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isHighlight
                            ? chipColor.opacity(chipSeverity == .high ? 0.65 : 0.45)
                            : Color.white.opacity(0.12),
                        lineWidth: (chipSeverity == .high || isDoubleTabArmed) && index == 0 ? 1.2 : 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                let frame = geo.frame(in: .named("CaretPillRoot"))
                Color.clear
                    .onAppear { onUpdateChipFrame?(index, frame) }
                    .onChange(of: frame) { _, newFrame in onUpdateChipFrame?(index, newFrame) }
            }
        )
        .help(index == 0
              ? "Click chuột, \(acceptShortcut.shortBadge) hoặc ⌥1 để chèn '\(item.text)'"
              : "Click chuột hoặc ⌥\(index + 1) để chèn '\(item.text)'")
    }

    private var displayContent: String {
        if text.isEmpty {
            switch state {
            case .transcript:
                return "Đang gõ văn bản..."
            case .working:
                return "Đang làm mượt câu..."
            case .done:
                return "Sẵn sàng"
            }
        }
        return text
    }

    @ViewBuilder
    private var rightSection: some View {
        switch state {
        case .transcript:
            PillActionControls(
                currentTone: currentTone,
                onUndo: onUndo,
                onCycleTone: onCycleTone,
                onUpdateUndoFrame: onUpdateUndoButtonFrame,
                onUpdateToneFrame: onUpdateToneButtonFrame
            )
        case .working:
            Text("AI Polish")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 165/255, green: 180/255, blue: 252/255))
        case .done:
            HStack(spacing: 6) {
                Text("✓")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 52/255, green: 211/255, blue: 153/255))
                PillActionControls(
                    currentTone: currentTone,
                    onUndo: onUndo,
                    onCycleTone: onCycleTone,
                    onUpdateUndoFrame: onUpdateUndoButtonFrame,
                    onUpdateToneFrame: onUpdateToneButtonFrame
                )
            }
        }
    }
}

/// AppKit NSVisualEffectView wrapper for SwiftUI with clean rounded masking.
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var cornerRadius: CGFloat

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        cornerRadius: CGFloat = 20
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = true
    }
}
