import SwiftUI
import VFlowCore

/// Action buttons in the right section of the Caret Pill HUD.
public struct PillActionControls: View {
    public var currentTone: PolishTone
    public var onUndo: () -> Void
    public var onCycleTone: () -> Void
    public var onUpdateUndoFrame: ((CGRect) -> Void)?
    public var onUpdateToneFrame: ((CGRect) -> Void)?

    public init(
        currentTone: PolishTone = .natural,
        onUndo: @escaping () -> Void = {},
        onCycleTone: @escaping () -> Void = {},
        onUpdateUndoFrame: ((CGRect) -> Void)? = nil,
        onUpdateToneFrame: ((CGRect) -> Void)? = nil
    ) {
        self.currentTone = currentTone
        self.onUndo = onUndo
        self.onCycleTone = onCycleTone
        self.onUpdateUndoFrame = onUpdateUndoFrame
        self.onUpdateToneFrame = onUpdateToneFrame
    }

    public var body: some View {
        HStack(spacing: 5) {
            // Undo button
            Button(action: onUndo) {
                HStack(spacing: 2) {
                    Text("⌘Z")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 226/255, green: 232/255, blue: 240/255))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("CaretPillRoot"))
                    Color.clear
                        .onAppear { onUpdateUndoFrame?(frame) }
                        .onChange(of: frame) { _, newFrame in onUpdateUndoFrame?(newFrame) }
                }
            )
            .help("Hoàn tác văn bản vừa sửa")

            // Cycle Tone button
            Button(action: onCycleTone) {
                HStack(spacing: 3) {
                    Text("✦")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 165/255, green: 180/255, blue: 252/255))
                    Text(currentTone.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 226/255, green: 232/255, blue: 240/255))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 165/255, green: 180/255, blue: 252/255).opacity(0.3), lineWidth: 0.5)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("CaretPillRoot"))
                    Color.clear
                        .onAppear { onUpdateToneFrame?(frame) }
                        .onChange(of: frame) { _, newFrame in onUpdateToneFrame?(newFrame) }
                }
            )
            .help("Nhấn chuột để chuyển giọng điệu: Tự nhiên -> Lịch sự -> Ngắn gọn")
        }
    }
}
