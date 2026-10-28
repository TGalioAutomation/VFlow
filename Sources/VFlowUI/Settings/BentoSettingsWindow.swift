import SwiftUI
import AppKit
import VFlowCore
import VFlowPlatform

/// Redesigned VFlow Control Center & Settings Dashboard using macOS Modern Sidebar + Dynamic Liquid Glass Bento Grid.
public struct BentoSettingsView: View {
    @ObservedObject private var store = VFlowControlCenterStore.shared

    // Non-destructive Live Sandbox Studio State
    @State private var sandboxText: String = "to đang thu go tieng viet không cau"
    @State private var sandboxState: CaretPillState = .transcript
    @State private var sandboxAudioLevel: Float = 0.55
    @State private var sandboxSuggestions: [SuggestionItem] = []
    @State private var sandboxCurrentWord: String = "cau"
    @State private var sandboxSeverity: SuggestionSeverity = .high
    @State private var sandboxAIInferenceTask: Task<Void, Never>? = nil
    @State private var sandboxLastLatencyMs: Double = 0.0

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left Liquid Glass Sidebar
            sidebarPanel

            Divider()
                .background(Color.white.opacity(0.08))

            // Right Dynamic Content Area
            VStack(spacing: 0) {
                topTelemetryHeaderBar

                if let banner = store.statusBannerMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(VFlowTheme.emeraldOk)
                        Text(banner)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(VFlowTheme.emeraldOk.opacity(0.14))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        switch store.selectedTab {
                        case .dashboard:
                            dashboardTabContent
                        case .inputAndMacros:
                            inputAndMacrosTabContent
                        case .aiAndVoice:
                            aiAndVoiceTabContent
                        case .sandboxStudio:
                            sandboxStudioTabContent
                        }
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VFlowTheme.canvasBg)
        }
        .frame(minWidth: 920, minHeight: 660)
        .background(VFlowTheme.canvasBg)
        .onAppear {
            store.refreshTelemetry()
            recomputeSandboxSuggestions(for: sandboxText)
        }
        // Hidden keyboard shortcut buttons for ⌘1 - ⌘4 tab navigation
        .background(
            HStack {
                Button("") { store.selectedTab = .dashboard }.keyboardShortcut("1", modifiers: .command)
                Button("") { store.selectedTab = .inputAndMacros }.keyboardShortcut("2", modifiers: .command)
                Button("") { store.selectedTab = .aiAndVoice }.keyboardShortcut("3", modifiers: .command)
                Button("") { store.selectedTab = .sandboxStudio }.keyboardShortcut("4", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    // MARK: - Left Sidebar

    private var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Identity Header
            HStack(spacing: 12) {
                loadAssetImage(named: "app_icon_nobg.png", fallbackSystemName: "waveform.circle.fill")
                    .frame(width: 42, height: 42)
                    .shadow(color: VFlowTheme.cyanAccent.opacity(0.35), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("VFlow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("1.0.0")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(VFlowTheme.cyanAccent.opacity(0.2))
                            .foregroundColor(VFlowTheme.cyanAccent)
                            .clipShape(Capsule())
                    }
                    Text("Control Center & AI Hub")
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            Divider()
                .background(Color.white.opacity(0.08))

            // Navigation Items
            VStack(alignment: .leading, spacing: 6) {
                Text("ĐIỀU HƯỚNG")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.horizontal, 8)

                ForEach(ControlCenterTab.allCases) { tab in
                    sidebarTabRow(tab)
                }
            }

            Spacer()

            // Quick Input Mode Switcher Footer Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CHẾ ĐỘ GÕ HIỆN TẠI")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(VFlowTheme.cyanAccent)
                    Spacer()
                    KeyboardShortcutCap("⌥Z", accent: VFlowTheme.cyanAccent)
                }

                HStack(spacing: 5) {
                    ForEach(InputMethod.allCases, id: \.self) { method in
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                store.inputMethod = method
                            }
                        }) {
                            Text(method.shortBadge)
                                .font(.system(size: 11, weight: store.inputMethod == method ? .bold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    store.inputMethod == method
                                        ? VFlowTheme.cyanAccent.opacity(0.26)
                                        : Color.white.opacity(0.05)
                                )
                                .foregroundColor(
                                    store.inputMethod == method
                                        ? VFlowTheme.cyanAccent
                                        : .white.opacity(0.75)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(
                                            store.inputMethod == method ? VFlowTheme.cyanAccent.opacity(0.45) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(16)
        .frame(width: 236)
        .frame(maxHeight: .infinity)
        .background(VFlowTheme.sidebarBg)
    }

    private func sidebarTabRow(_ tab: ControlCenterTab) -> some View {
        let isSelected = store.selectedTab == tab
        return Button(action: {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                store.selectedTab = tab
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? VFlowTheme.cyanAccent.opacity(0.22) : Color.white.opacity(0.05))
                        .frame(width: 28, height: 28)
                    Image(systemName: tab.iconName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(isSelected ? VFlowTheme.cyanAccent : .white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(tab.title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    Text(tab.subtitle)
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                Text(tab.shortcutLabel)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? VFlowTheme.cyanAccent : .white.opacity(0.65))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [VFlowTheme.cyanAccent.opacity(0.16), VFlowTheme.purpleAccent.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? VFlowTheme.cyanAccent.opacity(0.38) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Top Telemetry Header Bar

    private var topTelemetryHeaderBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedTab.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(store.selectedTab.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            ControlStatusPill(
                label: "Accessibility",
                value: store.isAccessibilityTrusted ? "ĐÃ CẤP" : "CHƯA CẤP",
                level: store.isAccessibilityTrusted ? .healthy : .inactive
            )

            ControlStatusPill(
                label: "EventTap",
                value: store.isEventTapActive ? "ACTIVE" : "PAUSED",
                level: store.isEventTapActive ? .healthy : .warning
            )

            ControlStatusPill(
                label: "Neural AI",
                value: store.isNeuralEngineAvailable && store.isNeuralPolishEnabled
                    ? "\(store.inputMethod == .off ? "EN" : "VI")·AI"
                    : "RULE",
                level: store.isNeuralEngineAvailable && store.isNeuralPolishEnabled ? .healthy : .warning
            )

            Button(action: { store.repairPermissionsAndEventTap() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text(store.isAccessibilityTrusted && store.isEventTapActive ? "Đồng bộ" : "Cấp quyền")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VFlowTheme.cyanAccent.opacity(0.18))
                .foregroundColor(VFlowTheme.cyanAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.025))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - TAB 1: Dashboard Overview

    private var dashboardTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 4 KPI Metric Tiles
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ControlMetricTile(
                    title: "QUYỀN HỆ THỐNG",
                    value: store.isAccessibilityTrusted ? "Đã xác thực" : "Cần cấp quyền",
                    caption: store.isEventTapActive ? "CGEventTap đang bắt phím" : "Chờ kích hoạt EventTap",
                    systemIcon: "checkmark.shield.fill",
                    accentColor: store.isAccessibilityTrusted && store.isEventTapActive ? VFlowTheme.emeraldOk : VFlowTheme.amberWarn
                )

                ControlMetricTile(
                    title: "BỘ GÕ ĐANG DÙNG",
                    value: store.inputMethod.displayName,
                    caption: store.autoEnglishRestore ? "Song ngữ VI + EN tự động" : "Chỉ gõ đơn ngữ",
                    systemIcon: "keyboard.fill",
                    accentColor: VFlowTheme.cyanAccent
                )

                ControlMetricTile(
                    title: "APPLE NEURAL ENGINE",
                    value: store.isNeuralEngineAvailable ? "FoundationModels 3B" : "Rule Engine",
                    caption: "Cache \(store.aiCachedEntries)/\(store.aiMaxCacheEntries) • \(store.aiTotalInferences) lượt",
                    systemIcon: "cpu.fill",
                    accentColor: VFlowTheme.purpleAccent
                )

                ControlMetricTile(
                    title: "TỪ ĐIỂN GÕ TẮT",
                    value: "\(store.activeMacroCount) từ hoạt động",
                    caption: store.expandMacrosOnSpace ? "Tự động bung khi nhấn Space" : "Chỉ hiện trên Caret Pill",
                    systemIcon: "text.badge.plus",
                    accentColor: VFlowTheme.emeraldOk
                )
            }

            // 2-Column Bento Cards
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                // Quick Control Card
                ControlBentoCard(
                    title: "ĐIỀU KHIỂN NHANH BỘ GÕ & AI",
                    subtitle: "Đồng bộ tức thì với Menu Bar, Caret Pill và toàn bộ ứng dụng",
                    systemIcon: "slider.horizontal.3",
                    accentColor: VFlowTheme.cyanAccent
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiểu gõ hệ thống")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Picker("", selection: $store.inputMethod) {
                                ForEach(InputMethod.allCases, id: \.self) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Giọng điệu làm mượt câu (AI Polish)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Picker("", selection: $store.currentTone) {
                                ForEach(PolishTone.allCases, id: \.self) { tone in
                                    Text(tone.displayName).tag(tone)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        LiquidGlassToggleRow(
                            "Gõ Song ngữ Tự động (nhận diện từ Tiếng Anh theo ngữ cảnh)",
                            isOn: $store.autoEnglishRestore,
                            accentColor: VFlowTheme.cyanAccent
                        )

                        LiquidGlassToggleRow(
                            "Bật Apple Neural Engine ✨ sửa câu & thêm dấu tự động",
                            isOn: $store.isNeuralPolishEnabled,
                            accentColor: VFlowTheme.purpleAccent
                        )

                        HStack(spacing: 8) {
                            Button(action: { store.selectedTab = .inputAndMacros }) {
                                Label("Quản lý Gõ tắt (\(store.activeMacroCount))", systemImage: "text.badge.plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(VFlowTheme.cyanAccent.opacity(0.16))
                                    .foregroundColor(VFlowTheme.cyanAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button(action: { store.selectedTab = .sandboxStudio }) {
                                Label("Mở Live Sandbox", systemImage: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(VFlowTheme.purpleAccent.opacity(0.16))
                                    .foregroundColor(VFlowTheme.purpleAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                }

                // Shortcuts & System Health Card
                ControlBentoCard(
                    title: "BẢNG PHÍM TẮT & CHẨN ĐOÁN LIVE",
                    subtitle: "Thao tác siêu tốc không cần rời tay khỏi bàn phím",
                    systemIcon: "command.square.fill",
                    accentColor: VFlowTheme.purpleAccent
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        shortcutRow(
                            title: "Chuyển nhanh chế độ gõ Tiếng Việt ⇄ Tiếng Anh",
                            keys: "⌥ Z"
                        )
                        shortcutRow(
                            title: "Chọn nhanh gợi ý 1 / 2 / 3 trên thanh Caret Pill",
                            keys: "⌃1  ⌃2  ⌃3"
                        )
                        shortcutRow(
                            title: "Thu âm giọng nói Push-to-Talk (VI + EN)",
                            keys: "⌥ Space / Fn"
                        )
                        shortcutRow(
                            title: "Chuyển nhanh 4 mục trong Trung tâm Điều khiển",
                            keys: "⌘1 → ⌘4"
                        )

                        Divider().background(Color.white.opacity(0.08))

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.isAccessibilityTrusted && store.isEventTapActive
                                     ? "Mọi dịch vụ ngầm đang hoạt động tối ưu"
                                     : "Cần kiểm tra quyền Accessibility / EventTap")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(store.isAccessibilityTrusted && store.isEventTapActive ? VFlowTheme.emeraldOk : VFlowTheme.amberWarn)
                                Text("Độ trễ bắt phím < 0.2ms • Không lưu keylog nhạy cảm")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                            Button(action: { store.repairPermissionsAndEventTap() }) {
                                Text("Kiểm tra lại")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.09))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func shortcutRow(title: String, keys: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.82))
            Spacer()
            KeyboardShortcutCap(keys, accent: VFlowTheme.cyanAccent)
        }
        .padding(.vertical, 2)
    }

    // MARK: - TAB 2: Input Engine & Custom Macro Dictionary

    private var inputAndMacrosTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Card: Input Engine Rules
            ControlBentoCard(
                title: "CẤU HÌNH BỘ GÕ TIẾNG VIỆT & SONG NGỮ",
                subtitle: "Tùy chỉnh quy tắc bỏ dấu, khôi phục từ Tiếng Anh và tự động sửa từ không dấu",
                systemIcon: "keyboard.fill",
                accentColor: VFlowTheme.cyanAccent
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiểu gõ mặc định")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Picker("", selection: $store.inputMethod) {
                                ForEach(InputMethod.allCases, id: \.self) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quy tắc đặt vị trí dấu thanh")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Picker("", selection: $store.tonePlacement) {
                                Text("Kiểu mới (hòa, thủy)").tag(TonePlacement.modern)
                                Text("Kiểu cũ (hoà, thuỷ)").tag(TonePlacement.traditional)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    HStack(spacing: 24) {
                        LiquidGlassToggleRow(
                            "Gõ Song ngữ Tự động (nhận diện Tiếng Anh & giữ nguyên từ gốc)",
                            isOn: $store.autoEnglishRestore,
                            accentColor: VFlowTheme.cyanAccent
                        )

                        LiquidGlassToggleRow(
                            "Tự động bung từ gõ tắt ngay khi nhấn phím Cách (Space)",
                            isOn: $store.expandMacrosOnSpace,
                            accentColor: VFlowTheme.emeraldOk
                        )
                    }
                }
            }

            // Bottom Card: Custom Macro Dictionary Manager
            ControlBentoCard(
                title: "TỪ ĐIỂN GÕ TẮT CÁ NHÂN HÓA (CUSTOM MACROS)",
                subtitle: "Thêm các cụm từ viết tắt thường dùng (ví dụ: dc → được, vn → Việt Nam, email → địa chỉ của bạn)",
                systemIcon: "text.badge.plus",
                accentColor: VFlowTheme.emeraldOk,
                accessory: {
                    Button(action: { store.resetDefaultMacros() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Khôi phục mặc định")
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Controlled Form to Add/Update Macro
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Từ viết tắt (không dấu cách)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            TextField("VD: dc, vn, tks...", text: $store.newMacroTrigger)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 170)
                                .onSubmit { store.submitNewMacro() }
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(VFlowTheme.cyanAccent)
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cụm từ mở rộng")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            TextField("VD: được, Việt Nam, cảm ơn bạn...", text: $store.newMacroReplacement)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onSubmit { store.submitNewMacro() }
                        }

                        Button(action: { store.submitNewMacro() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                Text("Lưu Gõ Tắt")
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(VFlowTheme.emeraldOk.opacity(0.22))
                            .foregroundColor(VFlowTheme.emeraldOk)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(VFlowTheme.emeraldOk.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
                    }

                    // Form Validation Feedback Banner
                    if let error = store.macroValidationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(VFlowTheme.roseAlert)
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(VFlowTheme.roseAlert)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VFlowTheme.roseAlert.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else if let success = store.macroSuccessBanner {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(VFlowTheme.emeraldOk)
                            Text(success)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(VFlowTheme.emeraldOk)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VFlowTheme.emeraldOk.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Search filter
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.45))
                        TextField("Tìm kiếm trong \(store.macros.count) từ gõ tắt...", text: $store.macroSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white)
                        if !store.macroSearchQuery.isEmpty {
                            Button(action: { store.macroSearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    // Macro List
                    VStack(spacing: 6) {
                        ForEach(store.filteredMacros) { item in
                            macroItemRow(item)
                        }
                    }
                }
            }
        }
    }

    private func macroItemRow(_ item: CustomMacroItem) -> some View {
        HStack(spacing: 12) {
            LiquidGlassSwitch(
                isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in store.toggleMacro(item) }
                ),
                accentColor: VFlowTheme.emeraldOk
            )

            Text(item.trigger)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(item.isEnabled ? VFlowTheme.cyanAccent : .white.opacity(0.4))
                .frame(width: 90, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))

            Text(item.replacement)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(item.isEnabled ? .white : .white.opacity(0.45))

            Spacer()

            Text(item.isBuiltIn ? "Mặc định" : "Tùy chỉnh")
                .font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((item.isBuiltIn ? VFlowTheme.cyanAccent : VFlowTheme.purpleAccent).opacity(0.15))
                .foregroundColor(item.isBuiltIn ? VFlowTheme.cyanAccent : VFlowTheme.purpleAccent)
                .clipShape(Capsule())

            Button(action: { store.deleteMacro(item) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(VFlowTheme.roseAlert.opacity(0.85))
                    .padding(5)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - TAB 3: On-Device AI & Voice

    private var aiAndVoiceTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Card: Neural Polish & System Prompt Studio
            ControlBentoCard(
                title: "TRỢ LÝ NGÔN NGỮ APPLE NEURAL ENGINE & SYSTEM PROMPT STUDIO",
                subtitle: "Tùy chỉnh System Prompt định hướng nội dung gợi ý và tự động đổi màu mức độ cần sửa trên Caret Pill",
                systemIcon: "sparkles",
                accentColor: VFlowTheme.purpleAccent,
                accessory: {
                    HStack(spacing: 8) {
                        ControlStatusPill(
                            label: "macOS 27 fm CLI",
                            value: store.isFMCLIAvailable ? (store.useFMCLIEngine ? "ĐANG BẬT" : "SẴN SÀNG") : "KHÔNG CÓ",
                            level: store.isFMCLIAvailable ? (store.useFMCLIEngine ? .healthy : .warning) : .inactive
                        )
                        Button(action: { store.resetSystemPromptToPresetDefault() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Khôi phục Prompt")
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phong cách gợi ý câu (Polish Tone)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Picker("", selection: $store.currentTone) {
                                ForEach(PolishTone.allCases, id: \.self) { tone in
                                    Text(tone.displayName).tag(tone)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Kích hoạt Apple FoundationModels ✨ (Neural Polish)")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.white)
                                LiquidGlassSwitch(isOn: $store.isNeuralPolishEnabled, accentColor: VFlowTheme.purpleAccent)
                            }

                            HStack(spacing: 8) {
                                Text(store.isFMCLIAvailable ? "Tùy chọn dùng công cụ '/usr/bin/fm' CLI (macOS 27)" : "Công cụ '/usr/bin/fm' CLI (Chỉ hỗ trợ trên macOS 27+)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(store.isFMCLIAvailable ? .white.opacity(0.85) : .white.opacity(0.45))
                                LiquidGlassSwitch(
                                    isOn: Binding(
                                        get: { store.useFMCLIEngine && store.isFMCLIAvailable },
                                        set: { newVal in
                                            if store.isFMCLIAvailable {
                                                store.useFMCLIEngine = newVal
                                            }
                                        }
                                    ),
                                    accentColor: VFlowTheme.cyanAccent
                                )
                                .opacity(store.isFMCLIAvailable ? 1.0 : 0.4)
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // System Prompt Preset Selector Pills
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bộ mẫu System Prompt (Chọn nhanh quy tắc gợi ý & chấm mức độ chuẩn):")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("~\(store.systemPromptTokenCount) tokens")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(VFlowTheme.purpleAccent.opacity(0.18))
                                .foregroundColor(VFlowTheme.purpleAccent)
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 8) {
                            ForEach(SystemPromptPreset.allCases) { preset in
                                let isSelected = store.systemPromptPreset == preset
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                        store.selectSystemPromptPreset(preset)
                                        recomputeSandboxSuggestions(for: sandboxText)
                                    }
                                }) {
                                    Text(preset.displayName)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            isSelected
                                                ? VFlowTheme.purpleAccent.opacity(0.26)
                                                : Color.white.opacity(0.06)
                                        )
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .stroke(
                                                    isSelected ? VFlowTheme.purpleAccent.opacity(0.55) : Color.white.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(store.systemPromptPreset.subtitle)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Editable System Prompt TextField/TextEditor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nội dung System Prompt đang áp dụng (Chỉnh sửa tự do):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))

                        TextEditor(
                            text: Binding(
                                get: { store.customSystemPrompt },
                                set: { newVal in
                                    if store.customSystemPrompt != newVal {
                                        store.customSystemPrompt = newVal
                                        if store.systemPromptPreset != .custom && newVal != store.systemPromptPreset.defaultPrompt {
                                            store.systemPromptPreset = .custom
                                        }
                                        recomputeSandboxSuggestions(for: sandboxText)
                                    }
                                }
                            )
                        )
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                        .padding(8)
                        .frame(height: 66)
                        .background(Color.black.opacity(0.32))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(VFlowTheme.purpleAccent.opacity(0.32), lineWidth: 1)
                        )
                    }

                    // 3-Level Color-Only Severity Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Circle().fill(VFlowTheme.cyanAccent).frame(width: 8, height: 8)
                            Text("Màu Cyan: Câu chuẩn / Gợi ý từ thường")
                                .font(.system(size: 10.5))
                                .foregroundColor(.white.opacity(0.72))
                        }
                        HStack(spacing: 6) {
                            Circle().fill(VFlowTheme.amberWarn).frame(width: 8, height: 8)
                            Text("Màu Vàng Amber: Có 1 lỗi nhẹ / thiếu dấu")
                                .font(.system(size: 10.5))
                                .foregroundColor(.white.opacity(0.72))
                        }
                        HStack(spacing: 6) {
                            Circle().fill(VFlowTheme.roseAlert).frame(width: 8, height: 8)
                            Text("Màu Đỏ Rose: Sai chính tả nặng / Lệch System Prompt (Tự đẩy ✨ lên phím Tab)")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(VFlowTheme.roseAlert)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            // Middle Card: Real 4-Stage Pipeline Hub
            ControlBentoCard(
                title: "KIẾN TRÚC 4 TẦNG XỬ LÝ NGÔN NGỮ TRÊN MAC",
                subtitle: "100% xử lý cục bộ trên Apple Silicon — Không gọi API đám mây, bảo mật tuyệt đối",
                systemIcon: "cpu.fill",
                accentColor: VFlowTheme.cyanAccent
            ) {
                ModelHubView()
            }

            // Bottom Card: Push-to-Talk & Tap-to-Talk Voice Dictation Studio
            ControlBentoCard(
                title: "NHẬP LIỆU GIỌNG NÓI TOÀN CỤC (TAP-TO-TALK & PUSH-TO-TALK)",
                subtitle: "Nhấn ⌥ Space 1 lần để nói rảnh tay (nhấn lại để chèn), hoặc giữ ⌥ Space / Fn khi nói",
                systemIcon: "mic.fill",
                accentColor: VFlowTheme.emeraldOk,
                accessory: {
                    HStack(spacing: 8) {
                        ControlStatusPill(
                            label: "Mic",
                            value: store.isMicrophoneAuthorized ? "OK" : "CẦN CẤP",
                            level: store.isMicrophoneAuthorized ? .healthy : .warning
                        )
                        ControlStatusPill(
                            label: "Speech",
                            value: store.isSpeechAuthorized ? "OK" : "CẦN CẤP",
                            level: store.isSpeechAuthorized ? .healthy : .warning
                        )
                        if !store.isMicrophoneAuthorized || !store.isSpeechAuthorized {
                            Button(action: { store.requestVoicePermissions() }) {
                                Text("Cấp quyền Mic")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(VFlowTheme.amberWarn.opacity(0.2))
                                    .foregroundColor(VFlowTheme.amberWarn)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ngôn ngữ nhận diện giọng nói")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Picker("", selection: $store.dictationLanguage) {
                                Text("Tiếng Việt (vi-VN)").tag("vi-VN")
                                Text("English (en-US)").tag("en-US")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                        }

                        LiquidGlassToggleRow(
                            "Chế độ mô phỏng (Simulation)",
                            isOn: $store.voiceSimulationMode,
                            accentColor: VFlowTheme.amberWarn,
                            compact: true
                        )
                        .fixedSize()

                        Spacer()

                        Button(action: { store.toggleVoiceRecording() }) {
                            HStack(spacing: 6) {
                                Image(systemName: store.isRecordingVoice ? "stop.circle.fill" : "mic.circle.fill")
                                Text(store.isRecordingVoice ? "Dừng & Hoàn tất" : "Bắt đầu Thu âm (⌥Space)")
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background((store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk).opacity(0.22))
                            .foregroundColor(store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke((store.isRecordingVoice ? VFlowTheme.roseAlert : VFlowTheme.emeraldOk).opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Live Voice Transcript & Polished Output Preview Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            SilkSineWaveView(
                                state: store.isRecordingVoice ? .working : .done,
                                audioLevel: store.isRecordingVoice ? max(0.35, store.voiceAudioLevel) : 0.2
                            )
                            Text(store.voiceStatusMessage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(store.isRecordingVoice ? VFlowTheme.cyanAccent : .white.opacity(0.75))
                            Spacer()
                            if !store.voicePolishedTranscript.isEmpty {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(store.voicePolishedTranscript, forType: .string)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy văn bản")
                                    }
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !store.voiceLiveTranscript.isEmpty || !store.voicePolishedTranscript.isEmpty {
                            Divider().background(Color.white.opacity(0.08))
                            if !store.voiceLiveTranscript.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("Lời nói thô:")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 85, alignment: .leading)
                                    Text(store.voiceLiveTranscript)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.82))
                                }
                            }
                            if !store.voicePolishedTranscript.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("Sau AI Polish:")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(VFlowTheme.emeraldOk)
                                        .frame(width: 85, alignment: .leading)
                                    Text(store.voicePolishedTranscript)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.26))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: - TAB 4: Non-Destructive Live Sandbox Studio

    private var sandboxStudioTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ControlBentoCard(
                title: "PHÒNG THỬ NGHIỆM LIVE SANDBOX & CARET PILL 120FPS",
                subtitle: "Kiểm thử trực tiếp 3 tầng gợi ý (⚡ Gõ tắt, ✨ AI Polish toàn câu, 🔮 Gợi ý từ tiếp theo) ngay trong bảng điều khiển",
                systemIcon: "sparkles.rectangle.stack.fill",
                accentColor: VFlowTheme.purpleAccent,
                accessory: {
                    Button(action: triggerExternalCaretPillPreview) {
                        HStack(spacing: 5) {
                            Image(systemName: "macwindow.on.rectangle")
                            Text("Hiện thử Caret Pill trên màn hình")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(VFlowTheme.cyanAccent.opacity(0.18))
                        .foregroundColor(VFlowTheme.cyanAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    // Preset Scenario Chips
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mẫu câu kiểm thử thực tế (Bấm để nạp nhanh):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 8) {
                            presetScenarioButton("Sai nặng & Lệch chuẩn", sample: "to đang thu go tieng viet không cau")
                            presetScenarioButton("Không dấu", sample: "toi dang thu go tieng viet không dau")
                            presetScenarioButton("Khuyết từ & thiếu dấu", sample: "thực co đang hoạt động tot")
                            presetScenarioButton("Teencode & lỗi gõ", sample: "không  thị duoc hết text")
                            presetScenarioButton("Câu đã chuẩn", sample: "Tôi đang thử gõ tiếng Việt có dấu")
                        }
                    }

                    // Live Interactive Text Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Nhập hoặc chỉnh sửa câu thử nghiệm:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            Spacer()
                            if sandboxLastLatencyMs > 0 {
                                Text(String(format: "Neural Engine: %.0f ms", sandboxLastLatencyMs))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(VFlowTheme.emeraldOk)
                            }
                        }

                        TextField("Gõ câu Tiếng Việt hoặc Tiếng Anh tại đây...", text: $sandboxText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .onChange(of: sandboxText) { _, newValue in
                                recomputeSandboxSuggestions(for: newValue)
                            }
                    }

                    // Embedded Non-Destructive CaretPillView Preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Thanh Caret Pill HUD Trực tiếp (Bấm vào từng gợi ý để áp dụng ngay vào câu trên):")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        HStack {
                            Spacer()
                            CaretPillView(
                                state: $sandboxState,
                                text: $sandboxText,
                                audioLevel: $sandboxAudioLevel,
                                currentTone: $store.currentTone,
                                currentWord: sandboxCurrentWord,
                                suggestions: sandboxSuggestions,
                                inputMethod: store.inputMethod,
                                severity: sandboxSeverity,
                                onUndo: {
                                    sandboxText = "to đang thu go tieng viet không cau"
                                    recomputeSandboxSuggestions(for: sandboxText)
                                },
                                onCycleTone: {
                                    switch store.currentTone {
                                    case .natural: store.currentTone = .polite
                                    case .polite: store.currentTone = .concise
                                    case .concise: store.currentTone = .natural
                                    }
                                    recomputeSandboxSuggestions(for: sandboxText)
                                },
                                onSelectSuggestion: { item in
                                    applySandboxSuggestion(item)
                                },
                                onToggleInputMethod: {
                                    store.inputMethod = (store.inputMethod == .off) ? .telex : .off
                                }
                            )
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func presetScenarioButton(_ label: String, sample: String) -> some View {
        Button(action: {
            sandboxText = sample
            recomputeSandboxSuggestions(for: sample)
        }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(sandboxText == sample ? VFlowTheme.purpleAccent.opacity(0.25) : Color.white.opacity(0.07))
                .foregroundColor(sandboxText == sample ? VFlowTheme.purpleAccent : .white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recomputeSandboxSuggestions(for fullText: String) {
        let hasTrailingSpace = fullText.hasSuffix(" ")
        let words = fullText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let currentWord = hasTrailingSpace ? "" : (words.last ?? "")
        let sentenceWords = hasTrailingSpace ? words : Array(words.dropLast())

        sandboxCurrentWord = currentWord
        let immediateSeverity = SuggestionEngine.evaluateSeverity(
            rawSentence: fullText,
            tone: store.currentTone,
            preset: store.systemPromptPreset,
            customPrompt: store.customSystemPrompt
        )
        sandboxSeverity = immediateSeverity

        var immediate = SuggestionEngine.suggest(
            currentWord: currentWord,
            rawWord: currentWord,
            sentenceWords: sentenceWords,
            tone: store.currentTone,
            fullSentenceText: fullText,
            wordAfterCursor: "",
            promoteAIPolishOnHighSeverity: true
        )

        if !currentWord.isEmpty && immediate.count < 3 {
            let completions = OnDeviceAIEngine.spellCheckerCompletions(
                partialWord: currentWord,
                fullSentence: fullText,
                limit: 3
            )
            for comp in completions where immediate.count < 3 {
                if !immediate.contains(where: { $0.text.lowercased() == comp.lowercased() }) {
                    immediate.append(
                        SuggestionItem(
                            text: comp,
                            kind: .wordCompletion,
                            replaceCurrentWord: true,
                            targetWordToReplace: currentWord
                        )
                    )
                }
            }
        }
        sandboxSuggestions = immediate

        sandboxAIInferenceTask?.cancel()
        guard OnDeviceAIEngine.isFoundationModelAvailable, store.isNeuralPolishEnabled, words.count >= 2 else { return }
        let capturedText = fullText
        let capturedTone = store.currentTone

        sandboxAIInferenceTask = Task { @MainActor in
            let t0 = CFAbsoluteTimeGetCurrent()
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, self.sandboxText == capturedText else { return }
            if let aiResult = await OnDeviceAIEngine.shared.inferSentencePolishAndNextWord(
                rawSentence: capturedText,
                tone: capturedTone
            ) {
                guard !Task.isCancelled, self.sandboxText == capturedText else { return }
                self.sandboxLastLatencyMs = max(1.0, (CFAbsoluteTimeGetCurrent() - t0) * 1000.0)
                let mergedSeverity = max(self.sandboxSeverity, aiResult.severity)
                self.sandboxSeverity = mergedSeverity
                var merged = self.sandboxSuggestions
                let normalized = VietnameseTextPolisher.normalizePunctuation(capturedText)
                if !aiResult.polishedSentence.isEmpty,
                   aiResult.polishedSentence.lowercased() != normalized.lowercased() {
                    let aiItem = SuggestionItem(
                        text: aiResult.polishedSentence,
                        kind: .aiPolish,
                        replaceCurrentWord: false,
                        severity: max(.moderate, mergedSeverity)
                    )
                    if let idx = merged.firstIndex(where: { $0.kind == .aiPolish }) {
                        merged[idx] = aiItem
                    } else if mergedSeverity == .high {
                        merged.insert(aiItem, at: 0)
                        if merged.count > 3 { merged = Array(merged.prefix(3)) }
                    } else if merged.count >= 2 {
                        merged.insert(aiItem, at: 1)
                        if merged.count > 3 { merged = Array(merged.prefix(3)) }
                    } else {
                        merged.append(aiItem)
                    }
                    merged = SuggestionEngine.prioritizeForSeverity(merged, severity: mergedSeverity)
                }
                if currentWord.isEmpty,
                   !aiResult.nextWord.isEmpty,
                   !merged.contains(where: { $0.text.lowercased() == aiResult.nextWord.lowercased() }) {
                    let nextItem = SuggestionItem(text: aiResult.nextWord, kind: .nextWord, replaceCurrentWord: false)
                    if merged.count < 3 {
                        merged.append(nextItem)
                    } else {
                        merged[merged.count - 1] = nextItem
                    }
                }
                self.sandboxSuggestions = merged
                self.store.refreshTelemetry()
            }
        }
    }

    private func applySandboxSuggestion(_ item: SuggestionItem) {
        if item.kind == .aiPolish {
            sandboxText = item.text
        } else if item.replaceCurrentWord && !sandboxCurrentWord.isEmpty {
            let ns = sandboxText as NSString
            let range = ns.range(of: sandboxCurrentWord, options: .backwards)
            if range.location != NSNotFound {
                sandboxText = ns.replacingCharacters(in: range, with: item.text + " ")
            } else {
                sandboxText += (sandboxText.isEmpty ? "" : " ") + item.text + " "
            }
        } else if item.replaceLastCompletedWord && !item.targetWordToReplace.isEmpty {
            let ns = sandboxText as NSString
            let range = ns.range(of: item.targetWordToReplace, options: .backwards)
            if range.location != NSNotFound {
                sandboxText = ns.replacingCharacters(in: range, with: item.text)
                if !sandboxText.hasSuffix(" ") {
                    sandboxText += " "
                }
            } else {
                sandboxText += (sandboxText.isEmpty ? "" : " ") + item.text + " "
            }
        } else {
            let trimmed = sandboxText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                sandboxText = item.text + " "
            } else {
                sandboxText = trimmed + " " + item.text + " "
            }
        }
        recomputeSandboxSuggestions(for: sandboxText)
    }

    private func triggerExternalCaretPillPreview() {
        let words = sandboxText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let currentWord = sandboxText.hasSuffix(" ") ? "" : (words.last ?? "")
        let sentenceWords = sandboxText.hasSuffix(" ") ? words : Array(words.dropLast())
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let previewFrame = CGRect(x: screen.midX - 230, y: screen.minY + 120, width: 460, height: 52)

        CaretHUDModel.shared.updateOnTyping(
            currentWord: currentWord,
            rawWord: currentWord,
            sentenceWords: sentenceWords,
            inputMethod: store.inputMethod,
            caretFrame: previewFrame,
            fullSentenceText: sandboxText,
            wordAfterCursor: ""
        )
    }

    // MARK: - Asset Loader

    @ViewBuilder
    private func loadAssetImage(named name: String, fallbackSystemName: String) -> some View {
        if let image = loadNSImage(named: name) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: fallbackSystemName)
                .resizable()
                .scaledToFit()
                .foregroundColor(VFlowTheme.cyanAccent)
        }
    }

    private func loadNSImage(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension) {
            return NSImage(contentsOf: url)
        }
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(name),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return NSImage(contentsOf: resourceURL)
        }
        let workspaceAssetPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/" + name).path
        if FileManager.default.fileExists(atPath: workspaceAssetPath) {
            return NSImage(contentsOfFile: workspaceAssetPath)
        }
        return nil
    }
}

/// Window controller for the VFlow Control Center window.
@MainActor
public final class BentoSettingsWindowController: NSWindowController {
    public static let shared = BentoSettingsWindowController()

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 180, y: 160, width: 940, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VFlow — Trung tâm Điều khiển & AI On-Device"
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        window.contentView = NSHostingView(rootView: BentoSettingsView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showWindow(selecting tab: ControlCenterTab? = nil) {
        if let tab = tab {
            VFlowControlCenterStore.shared.selectedTab = tab
        }
        VFlowControlCenterStore.shared.refreshTelemetry()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
