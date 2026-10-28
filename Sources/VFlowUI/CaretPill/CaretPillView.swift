import SwiftUI
import VFlowCore

/// The Caret Pill HUD View implementing Prototype v8 — Clean Minimal Wave + Real-Time Suggestions.
public struct CaretPillView: View {
    @Binding public var state: CaretPillState
    @Binding public var text: String
    @Binding public var audioLevel: Float
    @Binding public var currentTone: PolishTone

    public var currentWord: String
    public var suggestions: [SuggestionItem]
    public var inputMethod: InputMethod
    public var onUndo: () -> Void
    public var onCycleTone: () -> Void
    public var onSelectSuggestion: (SuggestionItem) -> Void
    public var onToggleInputMethod: () -> Void

    public init(
        state: Binding<CaretPillState>,
        text: Binding<String>,
        audioLevel: Binding<Float>,
        currentTone: Binding<PolishTone>,
        currentWord: String = "",
        suggestions: [SuggestionItem] = [],
        inputMethod: InputMethod = .telex,
        onUndo: @escaping () -> Void = {},
        onCycleTone: @escaping () -> Void = {},
        onSelectSuggestion: @escaping (SuggestionItem) -> Void = { _ in },
        onToggleInputMethod: @escaping () -> Void = {}
    ) {
        self._state = state
        self._text = text
        self._audioLevel = audioLevel
        self._currentTone = currentTone
        self.currentWord = currentWord
        self.suggestions = suggestions
        self.inputMethod = inputMethod
        self.onUndo = onUndo
        self.onCycleTone = onCycleTone
        self.onSelectSuggestion = onSelectSuggestion
        self.onToggleInputMethod = onToggleInputMethod
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Block 1: Left 52x22px Silk Sine-Wave + VI/EN Mode Badge
            SilkSineWaveView(state: state, audioLevel: audioLevel)
                .padding(.leading, 8)

            Button(action: onToggleInputMethod) {
                let modeLabel = inputMethod == .off ? "EN" : "VI"
                let badgeText = OnDeviceAIEngine.isFoundationModelAvailable ? "\(modeLabel)·AI" : modeLabel
                Text(badgeText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(
                        inputMethod == .off
                            ? Color(red: 148/255, green: 163/255, blue: 184/255)
                            : Color(red: 56/255, green: 189/255, blue: 248/255)
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (inputMethod == .off ? Color.white.opacity(0.06) : Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.15))
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                inputMethod == .off
                                    ? Color.white.opacity(0.12)
                                    : Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.35),
                                lineWidth: 0.5
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("Chuyển nhanh VI ⇄ EN (⌥Z)")

            // Block 2: Center Interactive Suggestions or Live Text Area
            if !visibleSuggestions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(visibleSuggestions.enumerated()), id: \.element.id) { index, item in
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
        .frame(height: 40)
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
                .stroke(Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.35), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var visibleSuggestions: [SuggestionItem] {
        guard !suggestions.isEmpty else { return [] }
        let hasLongPolish = suggestions.prefix(2).contains { $0.kind == .aiPolish && $0.text.count > 12 }
        if hasLongPolish {
            return Array(suggestions.prefix(2))
        }
        return Array(suggestions.prefix(3))
    }

    @ViewBuilder
    private func suggestionChip(item: SuggestionItem, index: Int) -> some View {
        let isHighlight = (index == 0) || item.kind == .teencodeExpansion || item.kind == .aiPolish
        Button(action: { onSelectSuggestion(item) }) {
            HStack(spacing: 4) {
                if index == 0 {
                    Text("⇥")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 125/255, green: 211/255, blue: 252/255))
                } else {
                    Text("⌥\(index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.45))
                }

                if item.kind == .aiPolish {
                    Text("✨")
                        .font(.system(size: 10))
                } else if item.kind == .teencodeExpansion {
                    Text("⚡")
                        .font(.system(size: 10))
                }

                Text(item.text)
                    .font(.system(size: 12.5, weight: isHighlight ? .medium : .regular))
                    .foregroundColor(Color(red: 241/255, green: 245/255, blue: 249/255))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                item.kind == .aiPolish
                    ? Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.24)
                    : (isHighlight
                        ? Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.18)
                        : Color.white.opacity(0.07))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        item.kind == .aiPolish
                            ? Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.45)
                            : (isHighlight
                                ? Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.35)
                                : Color.white.opacity(0.12)),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Nhấn chuột hoặc ⌥\(index + 1) để chèn '\(item.text)'")
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
                onCycleTone: onCycleTone
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
                    onCycleTone: onCycleTone
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
