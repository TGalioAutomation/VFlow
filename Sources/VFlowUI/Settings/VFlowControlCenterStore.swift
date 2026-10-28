import Foundation
import AppKit
import SwiftUI
import VFlowCore
import VFlowPlatform

/// Navigation tabs in the redesigned VFlow Control Center.
public enum ControlCenterTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard = "dashboard"
    case inputAndMacros = "inputAndMacros"
    case aiAndVoice = "aiAndVoice"
    case sandboxStudio = "sandboxStudio"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard:
            return "Tổng quan Live"
        case .inputAndMacros:
            return "Bộ gõ & Gõ tắt"
        case .aiAndVoice:
            return "AI & Giọng nói"
        case .sandboxStudio:
            return "Live Sandbox"
        }
    }

    public var subtitle: String {
        switch self {
        case .dashboard:
            return "Trạng thái & Quyền hệ thống"
        case .inputAndMacros:
            return "Telex/VNI & Từ điển Macro"
        case .aiAndVoice:
            return "Apple Neural Engine & Voice"
        case .sandboxStudio:
            return "Thử nghiệm 3-Tier & HUD"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .inputAndMacros:
            return "keyboard.badge.ellipsis"
        case .aiAndVoice:
            return "cpu.fill"
        case .sandboxStudio:
            return "sparkles.rectangle.stack.fill"
        }
    }

    public var shortcutLabel: String {
        switch self {
        case .dashboard: return "⌘1"
        case .inputAndMacros: return "⌘2"
        case .aiAndVoice: return "⌘3"
        case .sandboxStudio: return "⌘4"
        }
    }
}

/// Centralized Single-Source Reactive Store for the VFlow Control Center, Menu Bar Popover, Caret Pill HUD, and EventTapHook.
@MainActor
public final class VFlowControlCenterStore: ObservableObject {
    public static let shared = VFlowControlCenterStore()

    // MARK: - Navigation State
    @Published public var selectedTab: ControlCenterTab = .dashboard

    // MARK: - Persisted Settings State
    @Published public var inputMethod: InputMethod {
        didSet {
            guard !isSyncingInternal else { return }
            UserDefaults.standard.set(inputMethod.rawValue, forKey: Keys.inputMethod)
            EventTapHook.shared.engine.inputMethod = inputMethod
            if inputMethod != .off {
                EventTapHook.shared.lastActiveVietnameseMethod = inputMethod
            }
            CaretHUDModel.shared.inputMethod = inputMethod
            MenuBarCoordinator.shared.syncFromStore()
        }
    }

    @Published public var tonePlacement: TonePlacement {
        didSet {
            UserDefaults.standard.set(tonePlacement.rawValue, forKey: Keys.tonePlacement)
            EventTapHook.shared.engine.tonePlacement = tonePlacement
        }
    }

    @Published public var autoEnglishRestore: Bool {
        didSet {
            UserDefaults.standard.set(autoEnglishRestore, forKey: Keys.autoEnglishRestore)
            EventTapHook.shared.engine.autoEnglishRestore = autoEnglishRestore
        }
    }

    @Published public var expandMacrosOnSpace: Bool {
        didSet {
            CustomMacroRegistry.shared.expandMacrosOnSpace = expandMacrosOnSpace
        }
    }

    @Published public var currentTone: PolishTone {
        didSet {
            UserDefaults.standard.set(currentTone.rawValue, forKey: Keys.currentTone)
            CaretHUDModel.shared.currentTone = currentTone
            MenuBarCoordinator.shared.syncFromStore()
        }
    }

    @Published public var isNeuralPolishEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNeuralPolishEnabled, forKey: Keys.isNeuralPolishEnabled)
            OnDeviceAIEngine.isNeuralPolishEnabled = isNeuralPolishEnabled
        }
    }

    @Published public var systemPromptPreset: SystemPromptPreset {
        didSet {
            UserDefaults.standard.set(systemPromptPreset.rawValue, forKey: Keys.systemPromptPreset)
            OnDeviceAIEngine.activeSystemPromptPreset = systemPromptPreset
        }
    }

    @Published public var customSystemPrompt: String {
        didSet {
            UserDefaults.standard.set(customSystemPrompt, forKey: Keys.customSystemPrompt)
            OnDeviceAIEngine.customSystemPrompt = customSystemPrompt
            updatePromptTokenCount()
        }
    }

    @Published public var useFMCLIEngine: Bool {
        didSet {
            UserDefaults.standard.set(useFMCLIEngine, forKey: Keys.useFMCLIEngine)
            OnDeviceAIEngine.useFMCLIEngine = useFMCLIEngine
        }
    }

    @Published public var dictationLanguage: String {
        didSet {
            UserDefaults.standard.set(dictationLanguage, forKey: Keys.dictationLanguage)
            VoiceDictationService.shared.setDictationLanguage(dictationLanguage)
        }
    }

    @Published public var voiceSimulationMode: Bool {
        didSet {
            UserDefaults.standard.set(voiceSimulationMode, forKey: Keys.voiceSimulationMode)
            VoiceDictationService.shared.isSimulationMode = voiceSimulationMode
        }
    }

    // MARK: - Live Telemetry State
    @Published public private(set) var isAccessibilityTrusted: Bool = false
    @Published public private(set) var isEventTapActive: Bool = false
    @Published public private(set) var isNeuralEngineAvailable: Bool = false
    @Published public private(set) var isFMCLIAvailable: Bool = false
    @Published public private(set) var systemPromptTokenCount: Int = 0
    @Published public private(set) var aiCachedEntries: Int = 0
    @Published public private(set) var aiMaxCacheEntries: Int = 128
    @Published public private(set) var aiTotalInferences: Int = 0
    @Published public private(set) var aiLastLatencyMs: Double = 0.0
    @Published public private(set) var isRecordingVoice: Bool = false
    @Published public private(set) var isMicrophoneAuthorized: Bool = false
    @Published public private(set) var isSpeechAuthorized: Bool = false
    @Published public var voiceLiveTranscript: String = ""
    @Published public var voicePolishedTranscript: String = ""
    @Published public var voiceStatusMessage: String = "Sẵn sàng (Nhấn ⌥Space hoặc giữ Fn để nói)"
    @Published public var voiceAudioLevel: Float = 0.0
    @Published public private(set) var statusBannerMessage: String? = nil

    // MARK: - Custom Macro Manager State & Form Validation
    @Published public private(set) var macros: [CustomMacroItem] = []
    @Published public var macroSearchQuery: String = ""
    @Published public var newMacroTrigger: String = "" {
        didSet {
            if macroValidationError != nil {
                macroValidationError = nil
            }
        }
    }
    @Published public var newMacroReplacement: String = "" {
        didSet {
            if macroValidationError != nil {
                macroValidationError = nil
            }
        }
    }
    @Published public private(set) var macroValidationError: String? = nil
    @Published public private(set) var macroSuccessBanner: String? = nil

    private var telemetryTimer: Timer?
    private var isSyncingInternal = false

    private enum Keys {
        static let inputMethod = "vflow.settings.inputMethod.v2"
        static let tonePlacement = "vflow.settings.tonePlacement.v2"
        static let autoEnglishRestore = "vflow.settings.autoEnglishRestore.v2"
        static let currentTone = "vflow.settings.currentTone.v2"
        static let isNeuralPolishEnabled = "vflow.settings.isNeuralPolishEnabled.v2"
        static let systemPromptPreset = "vflow.settings.systemPromptPreset.v1"
        static let customSystemPrompt = "vflow.settings.customSystemPrompt.v1"
        static let useFMCLIEngine = "vflow.settings.useFMCLIEngine.v1"
        static let dictationLanguage = "vflow.settings.dictationLanguage.v2"
        static let voiceSimulationMode = "vflow.settings.voiceSimulationMode.v3"
    }

    public init() {
        let defaults = UserDefaults.standard

        let savedMethod = defaults.string(forKey: Keys.inputMethod).flatMap(InputMethod.init(rawValue:)) ?? .telex
        let savedPlacement = defaults.string(forKey: Keys.tonePlacement).flatMap(TonePlacement.init(rawValue:)) ?? .modern
        let savedAutoEN = defaults.object(forKey: Keys.autoEnglishRestore) as? Bool ?? true
        let savedTone = defaults.string(forKey: Keys.currentTone).flatMap(PolishTone.init(rawValue:)) ?? .natural
        let savedNeuralPolish = defaults.object(forKey: Keys.isNeuralPolishEnabled) as? Bool ?? true
        let savedPreset = defaults.string(forKey: Keys.systemPromptPreset).flatMap(SystemPromptPreset.init(rawValue:)) ?? .standard
        let savedCustomPrompt = defaults.string(forKey: Keys.customSystemPrompt) ?? savedPreset.defaultPrompt
        let savedUseFMCLI = defaults.object(forKey: Keys.useFMCLIEngine) as? Bool ?? false
        let savedDictationLang = defaults.string(forKey: Keys.dictationLanguage) ?? "vi-VN"
        let savedVoiceSim = defaults.object(forKey: Keys.voiceSimulationMode) as? Bool ?? false

        self.inputMethod = savedMethod
        self.tonePlacement = savedPlacement
        self.autoEnglishRestore = savedAutoEN
        self.expandMacrosOnSpace = CustomMacroRegistry.shared.expandMacrosOnSpace
        self.currentTone = savedTone
        self.isNeuralPolishEnabled = savedNeuralPolish
        self.systemPromptPreset = savedPreset
        self.customSystemPrompt = savedCustomPrompt
        self.useFMCLIEngine = savedUseFMCLI && OnDeviceAIEngine.isFMCLIAvailable
        self.dictationLanguage = savedDictationLang
        self.voiceSimulationMode = savedVoiceSim
        self.macros = CustomMacroRegistry.shared.allItems()

        // Apply loaded settings immediately to runtime services
        EventTapHook.shared.engine.inputMethod = savedMethod
        if savedMethod != .off {
            EventTapHook.shared.lastActiveVietnameseMethod = savedMethod
        }
        EventTapHook.shared.engine.tonePlacement = savedPlacement
        EventTapHook.shared.engine.autoEnglishRestore = savedAutoEN
        CaretHUDModel.shared.inputMethod = savedMethod
        CaretHUDModel.shared.currentTone = savedTone
        OnDeviceAIEngine.isNeuralPolishEnabled = savedNeuralPolish
        OnDeviceAIEngine.activeSystemPromptPreset = savedPreset
        OnDeviceAIEngine.customSystemPrompt = savedCustomPrompt
        OnDeviceAIEngine.useFMCLIEngine = savedUseFMCLI && OnDeviceAIEngine.isFMCLIAvailable
        VoiceDictationService.shared.setDictationLanguage(savedDictationLang)
        VoiceDictationService.shared.isSimulationMode = savedVoiceSim

        refreshTelemetry()
        updatePromptTokenCount()
        startTelemetryPolling()
    }

    public func selectSystemPromptPreset(_ preset: SystemPromptPreset) {
        systemPromptPreset = preset
        if preset != .custom {
            customSystemPrompt = preset.defaultPrompt
        }
    }

    public func resetSystemPromptToPresetDefault() {
        let targetPreset = systemPromptPreset == .custom ? .standard : systemPromptPreset
        systemPromptPreset = targetPreset
        customSystemPrompt = targetPreset.defaultPrompt
        showTemporaryBanner("Đã khôi phục System Prompt về mặc định (\(targetPreset.displayName)).")
    }

    public func updatePromptTokenCount() {
        let promptText = customSystemPrompt
        systemPromptTokenCount = OnDeviceAIEngine.estimateTokenCount(for: promptText)
        if OnDeviceAIEngine.isFMCLIAvailable && useFMCLIEngine {
            Task { @MainActor in
                let exactCount = await OnDeviceAIEngine.shared.countTokensViaFMCLI(promptText)
                if self.customSystemPrompt == promptText {
                    self.systemPromptTokenCount = exactCount
                }
            }
        }
    }

    /// Synchronizes inputMethod when toggled externally (e.g. via `⌥Z` hotkey in `EventTapHook` or Caret Pill click).
    public func syncInputMethodFromExternal(_ method: InputMethod) {
        guard inputMethod != method else { return }
        isSyncingInternal = true
        inputMethod = method
        isSyncingInternal = false
        UserDefaults.standard.set(method.rawValue, forKey: Keys.inputMethod)
        CaretHUDModel.shared.inputMethod = method
        MenuBarCoordinator.shared.syncFromStore()
    }

    // MARK: - Telemetry & System Health Actions

    public func startTelemetryPolling() {
        telemetryTimer?.invalidate()
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTelemetry()
            }
        }
    }

    public func refreshTelemetry() {
        isAccessibilityTrusted = AccessibilityBridge.shared.isAccessibilityGranted(prompt: false)
        isEventTapActive = EventTapHook.shared.isTapActive
        isNeuralEngineAvailable = OnDeviceAIEngine.isFoundationModelAvailable
        isFMCLIAvailable = OnDeviceAIEngine.isFMCLIAvailable
        isRecordingVoice = VoiceDictationService.shared.isRecording
        isMicrophoneAuthorized = VoiceDictationService.shared.isMicrophoneAuthorized
        isSpeechAuthorized = VoiceDictationService.shared.isSpeechAuthorized
        voiceStatusMessage = VoiceDictationService.shared.statusMessage

        Task { @MainActor in
            let snap = await OnDeviceAIEngine.shared.telemetry()
            self.aiCachedEntries = snap.cachedEntries
            self.aiMaxCacheEntries = snap.maxCacheEntries
            self.aiTotalInferences = snap.totalInferences
            self.aiLastLatencyMs = snap.lastLatencyMs
        }
    }

    public func requestVoicePermissions() {
        VoiceDictationService.shared.requestAuthorization { [weak self] granted in
            Task { @MainActor in
                self?.refreshTelemetry()
                if granted {
                    self?.showTemporaryBanner("Đã cấp quyền Microphone & Nhận diện giọng nói thành công!")
                } else {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                    self?.showTemporaryBanner("Vui lòng bật quyền Microphone & Speech Recognition trong Cài đặt Hệ thống.")
                }
            }
        }
    }

    public func updateVoicePartial(text: String, audioLevel: Float) {
        self.voiceLiveTranscript = text
        self.voiceAudioLevel = audioLevel
        self.isRecordingVoice = VoiceDictationService.shared.isRecording
    }

    public func updateVoiceFinal(raw: String, polished: String) {
        self.voiceLiveTranscript = raw
        self.voicePolishedTranscript = polished
        self.voiceAudioLevel = 0.0
        self.isRecordingVoice = false
        self.voiceStatusMessage = VoiceDictationService.shared.statusMessage
    }

    public func updateVoiceRecordingState(isRecording: Bool, status: String) {
        self.isRecordingVoice = isRecording
        self.voiceStatusMessage = status
        if isRecording {
            self.voiceLiveTranscript = ""
        } else {
            self.voiceAudioLevel = 0.0
        }
    }

    /// Attempts to start/restart the CGEventTap or prompts macOS Accessibility settings if permission is missing.
    public func repairPermissionsAndEventTap() {
        let trusted = AccessibilityBridge.shared.isAccessibilityGranted(prompt: true)
        isAccessibilityTrusted = trusted
        if !EventTapHook.shared.isTapActive {
            _ = EventTapHook.shared.start()
        }
        isEventTapActive = EventTapHook.shared.isTapActive

        if trusted && isEventTapActive {
            showTemporaryBanner("Đã kích hoạt thành công Accessibility & CGEventTap!")
        } else if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            showTemporaryBanner("Đã mở Cài đặt Quyền riêng tư & Bảo mật (Accessibility).")
        } else {
            showTemporaryBanner("Đang khởi động lại bộ bắt phím hệ thống...")
        }
    }

    public func prewarmNeuralEngine() {
        Task { @MainActor in
            await OnDeviceAIEngine.shared.prewarm()
            self.refreshTelemetry()
            self.showTemporaryBanner("Apple Neural Engine (FoundationModels) đã được làm nóng!")
        }
    }

    public func clearNeuralCache() {
        Task { @MainActor in
            await OnDeviceAIEngine.shared.clearCache()
            self.refreshTelemetry()
            self.showTemporaryBanner("Đã xóa bộ nhớ đệm (LRU Cache) của AI On-Device.")
        }
    }

    public func toggleVoiceRecording() {
        if VoiceDictationService.shared.isRecording {
            VoiceDictationService.shared.stopRecording()
        } else {
            VoiceDictationService.shared.isSimulationMode = voiceSimulationMode
            VoiceDictationService.shared.startRecording()
        }
        isRecordingVoice = VoiceDictationService.shared.isRecording
    }

    // MARK: - Custom Macro Dictionary Actions

    public var filteredMacros: [CustomMacroItem] {
        let query = macroSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return macros }
        return macros.filter {
            $0.trigger.lowercased().contains(query) || $0.replacement.lowercased().contains(query)
        }
    }

    public var activeMacroCount: Int {
        macros.filter(\.isEnabled).count
    }

    public func submitNewMacro() {
        let result = CustomMacroRegistry.shared.addOrUpdate(
            trigger: newMacroTrigger,
            replacement: newMacroReplacement
        )
        switch result {
        case .success(let item):
            macros = CustomMacroRegistry.shared.allItems()
            newMacroTrigger = ""
            newMacroReplacement = ""
            macroValidationError = nil
            showMacroSuccess("Đã lưu gõ tắt: \"\(item.trigger)\" → \"\(item.replacement)\"")
        case .failure(let error):
            macroValidationError = error.errorDescription
        }
    }

    public func toggleMacro(_ item: CustomMacroItem) {
        CustomMacroRegistry.shared.toggle(id: item.id)
        macros = CustomMacroRegistry.shared.allItems()
    }

    public func deleteMacro(_ item: CustomMacroItem) {
        CustomMacroRegistry.shared.remove(id: item.id)
        macros = CustomMacroRegistry.shared.allItems()
    }

    public func resetDefaultMacros() {
        CustomMacroRegistry.shared.resetToDefaults()
        macros = CustomMacroRegistry.shared.allItems()
        showMacroSuccess("Đã khôi phục bộ từ điển gõ tắt mặc định.")
    }

    private func showTemporaryBanner(_ text: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            statusBannerMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
            guard let self = self, self.statusBannerMessage == text else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.statusBannerMessage = nil
            }
        }
    }

    private func showMacroSuccess(_ text: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            macroSuccessBanner = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let self = self, self.macroSuccessBanner == text else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.macroSuccessBanner = nil
            }
        }
    }
}
