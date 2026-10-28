import SwiftUI
import VFlowCore

/// Displays the real 4-stage Apple Silicon On-Device Neural Pipeline powering VFlow.
public struct ModelHubView: View {
    @ObservedObject private var store = VFlowControlCenterStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Stage 1: Apple FoundationModels (Neural Engine LLM)
            pipelineStageRow(
                title: "Apple FoundationModels (SystemLanguageModel 3B)",
                badge: store.isNeuralEngineAvailable
                    ? (store.isNeuralPolishEnabled ? "ĐANG CHẠY TRÊN ANE" : "TẠM DỪNG")
                    : "RULE FALLBACK",
                badgeColor: store.isNeuralEngineAvailable && store.isNeuralPolishEnabled
                    ? VFlowTheme.emeraldOk
                    : VFlowTheme.amberWarn,
                icon: "brain.head.profile",
                description: "Suy luận ngôn ngữ tự nhiên trên Apple Neural Engine (@Generable OnDeviceAISuggestions, Greedy Decoding, bảo toàn 100% từ gốc, không gửi dữ liệu ra internet).",
                metrics: [
                    ("internaldrive", "Tích hợp macOS 26"),
                    ("memorychip", "Cache: \(store.aiCachedEntries)/\(store.aiMaxCacheEntries)"),
                    ("bolt.fill", store.aiLastLatencyMs > 0 ? String(format: "%.0f ms", store.aiLastLatencyMs) : "Debounce 220ms"),
                    ("number", "Lượt gọi: \(store.aiTotalInferences)")
                ],
                trailingAction: {
                    HStack(spacing: 6) {
                        Button(action: { store.prewarmNeuralEngine() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("Prewarm")
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(VFlowTheme.cyanAccent.opacity(0.18))
                            .foregroundColor(VFlowTheme.cyanAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(action: { store.clearNeuralCache() }) {
                            Text("Xóa Cache")
                                .font(.system(size: 10.5, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            )

            // Stage 2: Apple NSSpellChecker + NLLanguageRecognizer
            pipelineStageRow(
                title: "Apple NSSpellChecker & NaturalLanguage (VI + EN)",
                badge: "HOẠT ĐỘNG (<1ms)",
                badgeColor: VFlowTheme.cyanAccent,
                icon: "text.magnifyingglass",
                description: "Hoàn thành từ đang gõ dở theo ngữ cảnh câu song ngữ Tiếng Việt (\"vi\") và Tiếng Anh (\"en\") đồng bộ dưới 1 mili-giây.",
                metrics: [
                    ("globe.asia.australia.fill", "Từ điển: vi + en"),
                    ("bolt.fill", "Độ trễ: < 1 ms"),
                    ("lock.shield.fill", "100% Offline")
                ],
                trailingAction: { EmptyView() }
            )

            // Stage 3: VFlow Deterministic Bilingual FSM & Polisher
            pipelineStageRow(
                title: "VFlow Deterministic Bilingual FSM & Phrase Repair",
                badge: "HOẠT ĐỘNG (<0.2ms)",
                badgeColor: VFlowTheme.emeraldOk,
                icon: "character.cursor.ibeam",
                description: "Máy trạng thái Telex/VNI 65 âm vần, tự động khôi phục từ Tiếng Anh, điền từ nối bị khuyết và mở rộng \(store.activeMacroCount) từ gõ tắt.",
                metrics: [
                    ("keyboard", "Kiểu gõ: \(store.inputMethod.displayName)"),
                    ("text.badge.checkmark", "Macro bật: \(store.activeMacroCount)"),
                    ("bolt.fill", "Độ trễ: < 0.2 ms")
                ],
                trailingAction: { EmptyView() }
            )

            // Stage 4: Apple Speech & Audio Engine
            pipelineStageRow(
                title: "Apple SFSpeechRecognizer & AVAudioEngine",
                badge: store.isRecordingVoice ? "ĐANG THU ÂM" : "SẴN SÀNG",
                badgeColor: store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.purpleAccent,
                icon: "waveform.badge.mic",
                description: "Nhận diện giọng nói Push-to-Talk thời gian thực (⌥Space / Fn) kèm khử từ đệm (à, ừm) và chuẩn hóa dấu câu.",
                metrics: [
                    ("mic.fill", "Ngôn ngữ: \(store.dictationLanguage)"),
                    ("waveform", store.voiceSimulationMode ? "Chế độ: Simulation" : "Chế độ: Live Mic")
                ],
                trailingAction: { EmptyView() }
            )
        }
    }

    @ViewBuilder
    private func pipelineStageRow<Trailing: View>(
        title: String,
        badge: String,
        badgeColor: Color,
        icon: String,
        description: String,
        metrics: [(String, String)],
        @ViewBuilder trailingAction: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(badgeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)

                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.18))
                        .foregroundColor(badgeColor)
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { _, pair in
                        Label(pair.1, systemImage: pair.0)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.48))
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 8)

            trailingAction()
        }
        .padding(12)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(badgeColor.opacity(0.22), lineWidth: 1)
        )
    }
}
