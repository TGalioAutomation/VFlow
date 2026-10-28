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

    public var body: some View {
        let pillAccent = accentColor(for: effectiveSeverity)

        HStack(spacing: 8) {
            // Block 1: Left 52x22px Silk Sine-Wave + VI/EN Mode Badge
            SilkSineWaveView(
                state: state,
                audioLevel: audioLevel,
                severity: effectiveSeverity
            )
            .padding(.leading, 8)

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

            // Block 2: Center Interactive Suggestions or Live Text Area
            if !visibleSuggestions.isEmpty {
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
        .padding(.vertical, visibleSuggestions.first.map { $0.kind == .aiPolish && $0.text.count > 68 } == true ? 4 : 0)
        .fixedSize(horizontal: true, vertical: true)
        .background(
            // Deep Obsidian (#0D1324) 96% + Rounded UltraThin blur (no rectangular corner bleed)
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 20)
                Color(red: 13/255, green: 19/255, blue: 36/255).opacity(0.94)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    pillAccent.opacity(effectiveSeverity == .normal ? 0.35 : 0.72),
                    lineWidth: effectiveSeverity == .normal ? 1.0 : 1.35
                )
        )
        .shadow(
            color: effectiveSeverity == .normal ? Color.black.opacity(0.35) : pillAccent.opacity(0.28),
            radius: effectiveSeverity == .normal ? 8 : 11,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .coordinateSpace(name: "CaretPillRoot")
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
                    Text(acceptShortcut.shortBadge)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isDoubleTabArmed ? Color.white : chipColor)
                        .padding(.horizontal, isDoubleTabArmed ? 4 : 1)
                        .padding(.vertical, isDoubleTabArmed ? 1 : 0)
                        .background(
                            isDoubleTabArmed ? chipColor.opacity(0.85) : Color.clear
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
