import SwiftUI
import VFlowCore
import VFlowPlatform

/// Redesigned Liquid Glass Bento Menu Popover synchronized with `VFlowControlCenterStore`.
public struct BentoMenuView: View {
    @ObservedObject private var store = VFlowControlCenterStore.shared

    public var onOpenSettings: () -> Void
    public var onOpenMacros: () -> Void
    public var onToggleHUDPreview: () -> Void
    public var onQuit: () -> Void

    public init(
        inputMethod: Binding<InputMethod>? = nil,
        currentTone: Binding<PolishTone>? = nil,
        tonePlacement: Binding<TonePlacement>? = nil,
        onOpenSettings: @escaping () -> Void = {},
        onOpenMacros: @escaping () -> Void = {},
        onToggleHUDPreview: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenMacros = onOpenMacros
        self.onToggleHUDPreview = onToggleHUDPreview
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Brand Icon & Live Telemetry Badge
            HStack(spacing: 8) {
                menuBrandIcon
                    .frame(width: 24, height: 24)
                    .shadow(color: VFlowTheme.cyanAccent.opacity(0.35), radius: 4)

                Circle()
                    .fill(store.isAccessibilityTrusted && store.isEventTapActive ? VFlowTheme.emeraldOk : VFlowTheme.amberWarn)
                    .frame(width: 7, height: 7)
                    .shadow(color: (store.isAccessibilityTrusted && store.isEventTapActive ? VFlowTheme.emeraldOk : VFlowTheme.amberWarn).opacity(0.6), radius: 3)

                Text("VFlow Control Center")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text(store.isNeuralEngineAvailable && store.isNeuralPolishEnabled
                     ? "\(store.inputMethod == .off ? "EN" : "VI")·AI"
                     : store.inputMethod.shortBadge)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(VFlowTheme.cyanAccent.opacity(0.2))
                    .foregroundColor(VFlowTheme.cyanAccent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            Divider().background(Color.white.opacity(0.10))

            // Card 1: Input Method Selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BỘ GÕ HỆ THỐNG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VFlowTheme.cyanAccent)
                    Spacer()
                    Text("⌥Z")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }

                HStack(spacing: 6) {
                    ForEach(InputMethod.allCases, id: \.self) { method in
                        Button(action: {
                            store.inputMethod = method
                        }) {
                            Text(method.displayName)
                                .font(.system(size: 11, weight: store.inputMethod == method ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(store.inputMethod == method ? VFlowTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.06))
                                .foregroundColor(store.inputMethod == method ? VFlowTheme.cyanAccent : Color.white.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(store.inputMethod == method ? VFlowTheme.cyanAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(store.inputMethod == method ? [.isSelected] : [])
                    }
                }
            }

            // Card 2: AI Polish Tone Selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("PHONG CÁCH AI POLISH (✨)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VFlowTheme.purpleAccent)
                    Spacer()
                    LiquidGlassSwitch(isOn: $store.isNeuralPolishEnabled, accentColor: VFlowTheme.purpleAccent)
                }

                HStack(spacing: 6) {
                    ForEach(PolishTone.allCases, id: \.self) { tone in
                        Button(action: {
                            store.currentTone = tone
                            if !store.isNeuralPolishEnabled {
                                store.isNeuralPolishEnabled = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tone.badgeIcon)
                                    .font(.system(size: 10))
                                Text(tone.displayName)
                                    .font(.system(size: 11, weight: store.currentTone == tone ? .bold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(store.currentTone == tone ? VFlowTheme.purpleAccent.opacity(0.25) : Color.white.opacity(0.06))
                            .foregroundColor(store.currentTone == tone ? Color(red: 192/255, green: 132/255, blue: 252/255) : Color.white.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(store.currentTone == tone ? VFlowTheme.purpleAccent.opacity(0.45) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(store.currentTone == tone ? [.isSelected] : [])
                    }
                }
                .opacity(store.isNeuralPolishEnabled ? 1.0 : 0.48)
            }

            // Card 3: Quick Voice-to-Text Bar (⌥Space)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk)
                            .frame(width: 6, height: 6)
                        Text("NHẬP GIỌNG NÓI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(VFlowTheme.emeraldOk)
                    }
                    Spacer()
                    Text("⌥Space")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }

                HStack(spacing: 6) {
                    // Language selector pills (VI / EN)
                    ForEach([("vi-VN", "🇻🇳 Tiếng Việt"), ("en-US", "🇺🇸 English")], id: \.0) { code, label in
                        let isSelected = store.dictationLanguage == code
                        Button(action: {
                            store.dictationLanguage = code
                        }) {
                            Text(label)
                                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(isSelected ? VFlowTheme.cyanAccent.opacity(0.22) : Color.white.opacity(0.06))
                                .foregroundColor(isSelected ? VFlowTheme.cyanAccent : .white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? VFlowTheme.cyanAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }

                    Spacer(minLength: 2)

                    Button(action: {
                        let wasRecording = store.isRecordingVoice
                        store.toggleVoiceRecording()
                        if !wasRecording {
                            MenuBarCoordinator.shared.closePopover()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: store.isRecordingVoice ? "stop.circle.fill" : "mic.fill")
                                .font(.system(size: 10.5, weight: .bold))
                            Text(store.isRecordingVoice ? "Dừng" : "Nói ngay")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk).opacity(0.22))
                        .foregroundColor(store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke((store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk).opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Card 4: Quick Toggles Row (High-contrast left-aligned Liquid Glass Checkboxes)
            VStack(alignment: .leading, spacing: 8) {
                LiquidGlassToggleRow(
                    "Gõ Song ngữ VI + EN tự động",
                    isOn: $store.autoEnglishRestore,
                    accentColor: VFlowTheme.cyanAccent,
                    compact: true
                )

                LiquidGlassToggleRow(
                    "Tự bung gõ tắt (\(store.activeMacroCount) từ) khi nhấn Space",
                    isOn: $store.expandMacrosOnSpace,
                    accentColor: VFlowTheme.emeraldOk,
                    compact: true
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            // Actions: Macros, Test HUD & Open Control Center
            HStack(spacing: 6) {
                Button(action: onOpenMacros) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.badge.plus")
                        Text("Gõ tắt")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(VFlowTheme.emeraldOk.opacity(0.16))
                    .foregroundColor(VFlowTheme.emeraldOk)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onToggleHUDPreview) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Caret Pill")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Bảng ĐK")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(VFlowTheme.cyanAccent.opacity(0.18))
                    .foregroundColor(VFlowTheme.cyanAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.10))

            // Footer / Quit
            Button(action: onQuit) {
                HStack {
                    Text("Thoát VFlow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(VFlowTheme.roseAlert)
                    Spacer()
                    Text("⌘Q")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 310)
        .background(VFlowTheme.sidebarBg)
        .onAppear {
            store.refreshTelemetry()
        }
    }

    @ViewBuilder
    private var menuBrandIcon: some View {
        if let nsImage = loadMenuBrandNSImage() {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(VFlowTheme.cyanAccent)
        }
    }

    private func loadMenuBrandNSImage() -> NSImage? {
        let rawPaths: [String?] = [
            Bundle.main.url(forResource: "app_icon_nobg", withExtension: "png")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("app_icon_nobg.png").path,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/app_icon_nobg.png").path
        ]
        let candidatePaths = rawPaths.compactMap { $0 }

        guard let validPath = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return nil
        }
        return NSImage(contentsOfFile: validPath)
    }
}
