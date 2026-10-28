import Foundation
import Speech
import AVFoundation
import AppKit

/// Real-time Push-to-Talk & Tap-to-Talk voice dictation service powered by Apple `SFSpeechRecognizer` & `AVAudioEngine`.
/// Uses a standalone LaunchServices `--speech-worker` bundle instance when the main daemon runs under a parent IDE/shell
/// so macOS TCC validates `NSSpeechRecognitionUsageDescription` against `VFlow.app/Contents/Info.plist`.
public final class VoiceDictationService: ObservableObject, @unchecked Sendable {
    public static let shared = VoiceDictationService()

    @Published public var transcript: String = ""
    @Published public var lastFinalizedTranscript: String = ""
    @Published public var isRecording: Bool = false
    @Published public var audioLevel: Float = 0.0
    @Published public var currentLocaleIdentifier: String = "vi-VN"
    @Published public var statusMessage: String = "Sẵn sàng (Nhấn ⌥Space để nói)"

    /// Defaults to false so real Microphone + Apple Speech Recognition are always used unless explicitly testing simulation.
    public var isSimulationMode: Bool = false

    /// Fired on the main thread whenever partial speech recognition text or RMS audio level updates.
    public var onPartialTranscript: (@Sendable (_ partialText: String, _ audioLevel: Float) -> Void)?
    /// Fired on the main thread when a recording session finishes with non-empty recognized text.
    public var onFinalTranscript: (@Sendable (_ finalText: String) -> Void)?
    /// Fired on the main thread when recording state or status changes.
    public var onRecordingStateChanged: (@Sendable (_ isRecording: Bool, _ status: String) -> Void)?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var simulationTask: Task<Void, Never>?
    private var finalizationTask: Task<Void, Never>?
    private var hasEmittedFinalForCurrentSession: Bool = false
    private var workerAuthorizedSpeech: Bool = false
    private var workerAuthorizedMic: Bool = false
    private var ipcObserversInstalled: Bool = false
    private var lastAudioLevelPostTime: CFAbsoluteTime = 0

    private static let workerPidFile = "/tmp/vflow_speech_worker.pid"
    private static let voiceLogFile = "/tmp/vflow_voice.log"

    private enum IPCNotification {
        static let start = Notification.Name("com.apexdev.vflow.voice.start")
        static let stop = Notification.Name("com.apexdev.vflow.voice.stop")
        static let requestAuth = Notification.Name("com.apexdev.vflow.voice.requestAuth")
        static let partial = Notification.Name("com.apexdev.vflow.voice.partial")
        static let audioLevel = Notification.Name("com.apexdev.vflow.voice.audioLevel")
        static let finalResult = Notification.Name("com.apexdev.vflow.voice.final")
        static let workerStatus = Notification.Name("com.apexdev.vflow.voice.workerStatus")
    }

    /// Returns true ONLY when this process was launched by `launchd` (`getppid() == 1`) as a standalone `.app` bundle
    /// containing `NSSpeechRecognitionUsageDescription`.
    public static var canUseInProcessSpeechRecognizer: Bool {
        guard getppid() == 1 else { return false }
        return Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil
    }

    public init() {
        if Self.canUseInProcessSpeechRecognizer {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
        }
        setupMainDaemonIPCObserversIfNeeded()
    }

    public func logVoice(_ message: String) {
        let role = CommandLine.arguments.contains("--speech-worker") ? "WORKER" : "DAEMON"
        let line = "\(ISO8601DateFormatter().string(from: Date())) [\(role) pid=\(ProcessInfo.processInfo.processIdentifier) ppid=\(getppid())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: Self.voiceLogFile),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: Self.voiceLogFile)) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: Self.voiceLogFile))
        }
    }

    /// Returns true if Speech Recognition permission is authorized.
    public var isSpeechAuthorized: Bool {
        if Self.canUseInProcessSpeechRecognizer {
            return SFSpeechRecognizer.authorizationStatus() == .authorized
        }
        return workerAuthorizedSpeech
    }

    /// Returns true if Microphone permission is currently authorized.
    public var isMicrophoneAuthorized: Bool {
        if Self.canUseInProcessSpeechRecognizer {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return workerAuthorizedMic || AVAudioApplication.shared.recordPermission == .granted
    }

    /// Switches dictation locale between Vietnamese ("vi-VN") and English ("en-US").
    public func setDictationLanguage(_ localeIdentifier: String) {
        currentLocaleIdentifier = localeIdentifier
        if Self.canUseInProcessSpeechRecognizer {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        }
    }

    /// Pre-launches the standalone Speech Worker at app startup so it is ready before the user presses `⌥Space`.
    public func prewarmSpeechWorkerIfNeeded() {
        guard !Self.canUseInProcessSpeechRecognizer, !CommandLine.arguments.contains("--speech-worker") else { return }
        ensureSpeechWorkerLaunched {
            DistributedNotificationCenter.default().postNotificationName(
                IPCNotification.requestAuth,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    /// Requests microphone and speech recognition authorizations safely without triggering TCC SIGABRT.
    public func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        if Self.canUseInProcessSpeechRecognizer {
            SFSpeechRecognizer.requestAuthorization { speechStatus in
                let speechGranted = (speechStatus == .authorized)
                AVAudioApplication.requestRecordPermission { micGranted in
                    DispatchQueue.main.async {
                        completion(speechGranted && micGranted)
                    }
                }
            }
        } else {
            ensureSpeechWorkerLaunched {
                DistributedNotificationCenter.default().postNotificationName(
                    IPCNotification.requestAuth,
                    object: nil,
                    userInfo: nil,
                    deliverImmediately: true
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    completion(self.workerAuthorizedSpeech && self.isMicrophoneAuthorized)
                }
            }
        }
    }

    /// Toggles voice recording on/off.
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    /// Starts recording voice dictation on the main thread.
    public func startRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startRecording()
            }
            return
        }
        guard !isRecording else { return }

        finalizationTask?.cancel()
        finalizationTask = nil
        hasEmittedFinalForCurrentSession = false
        transcript = ""
        audioLevel = 0.30

        if isSimulationMode {
            isRecording = true
            statusMessage = "Đang mô phỏng giọng nói (\(currentLocaleIdentifier))..."
            onRecordingStateChanged?(true, statusMessage)
            startSimulation()
            return
        }

        // Delegate to LaunchServices Speech Worker when running under IDE/shell (getppid() != 1)
        if !Self.canUseInProcessSpeechRecognizer {
            isRecording = true
            let langLabel = currentLocaleIdentifier.hasPrefix("en") ? "English" : "Tiếng Việt"
            statusMessage = "🎙 Đang nghe (\(langLabel))... Hãy nói vào Microphone"
            onRecordingStateChanged?(true, statusMessage)

            let locale = currentLocaleIdentifier
            ensureSpeechWorkerLaunched { [weak self] in
                guard let self = self, self.isRecording else { return }
                self.logVoice("Posting IPC start (locale=\(locale)) to Speech Worker")
                DistributedNotificationCenter.default().postNotificationName(
                    IPCNotification.start,
                    object: nil,
                    userInfo: ["locale": locale],
                    deliverImmediately: true
                )
            }
            return
        }

        // Standalone LaunchServices bundle (getppid() == 1): run SFSpeechRecognizer + AVAudioEngine directly
        startStandaloneSpeechRecognition()
    }

    private func startStandaloneSpeechRecognition() {
        finalizationTask?.cancel()
        finalizationTask = nil
        hasEmittedFinalForCurrentSession = false
        transcript = ""
        audioLevel = 0.25

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission
        logVoice("startStandaloneSpeechRecognition speechStatus=\(speechStatus.rawValue) micStatus=\(micStatus.rawValue)")

        if speechStatus == .notDetermined || micStatus == .undetermined {
            statusMessage = "Đang xin quyền Microphone & Speech Recognition..."
            requestAuthorization { [weak self] granted in
                guard let self = self else { return }
                self.broadcastWorkerAuthStatus()
                if granted {
                    self.startStandaloneSpeechRecognition()
                } else {
                    self.isRecording = false
                    self.statusMessage = "Cần cấp quyền Microphone & Speech Recognition trong Cài đặt Hệ thống."
                    self.onRecordingStateChanged?(false, self.statusMessage)
                }
            }
            return
        }

        guard speechStatus == .authorized && micStatus == .granted else {
            isRecording = false
            statusMessage = "Chưa được cấp quyền Microphone hoặc Speech Recognition."
            logVoice("Denied permission: speech=\(speechStatus.rawValue) mic=\(micStatus.rawValue)")
            onRecordingStateChanged?(false, statusMessage)
            broadcastWorkerAuthStatus(extraStatus: statusMessage)
            return
        }

        broadcastWorkerAuthStatus()

        if speechRecognizer == nil || speechRecognizer?.locale.identifier != currentLocaleIdentifier {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocaleIdentifier))
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            statusMessage = "Bộ nhận diện giọng nói Apple Speech (\(currentLocaleIdentifier)) hiện không khả dụng."
            logVoice("Recognizer unavailable for locale \(currentLocaleIdentifier)")
            onRecordingStateChanged?(false, statusMessage)
            return
        }

        do {
            recognitionTask?.cancel()
            recognitionTask = nil

            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            self.recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                statusMessage = "Không tìm thấy thiết bị Microphone đầu vào."
                logVoice("Invalid recordingFormat sampleRate=\(recordingFormat.sampleRate)")
                onRecordingStateChanged?(false, statusMessage)
                return
            }

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                self.recognitionRequest?.append(buffer)
                let rmsLevel = Self.computeNormalizedRMS(from: buffer)
                let now = CFAbsoluteTimeGetCurrent()
                if now - self.lastAudioLevelPostTime >= 0.06 {
                    self.lastAudioLevelPostTime = now
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.isRecording else { return }
                        self.audioLevel = rmsLevel
                        self.onPartialTranscript?(self.transcript, rmsLevel)
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true
            let langLabel = currentLocaleIdentifier.hasPrefix("en") ? "English" : "Tiếng Việt"
            statusMessage = "🎙 Đang nghe (\(langLabel))... Nhấn ⌥Space để kết thúc"
            logVoice("AudioEngine & SFSpeechRecognizer started for locale=\(currentLocaleIdentifier)")
            onRecordingStateChanged?(true, statusMessage)

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if !text.isEmpty {
                            self.transcript = text
                            self.logVoice("PARTIAL isFinal=\(isFinal) text='\(text)'")
                            self.onPartialTranscript?(text, self.audioLevel)
                        }
                        if isFinal && !self.hasEmittedFinalForCurrentSession {
                            self.finishAndEmitTranscript()
                        }
                    }
                }
                if let error = error {
                    self.logVoice("Recognition error: \(error.localizedDescription)")
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if self.isRecording {
                            self.stopRecordingInternal()
                        } else if !self.hasEmittedFinalForCurrentSession {
                            self.finishAndEmitTranscript()
                        }
                    }
                }
            }
        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            isRecording = false
            statusMessage = "Lỗi khởi tạo âm thanh: \(error.localizedDescription)"
            logVoice("AudioEngine start catch: \(error.localizedDescription)")
            onRecordingStateChanged?(false, statusMessage)
        }
    }

    /// Stops voice dictation and finalizes transcript on the main thread.
    public func stopRecording() {
        if Thread.isMainThread {
            stopRecordingInternal()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.stopRecordingInternal()
            }
        }
    }

    private func stopRecordingInternal() {
        guard isRecording else { return }
        isRecording = false
        audioLevel = 0.0

        if isSimulationMode || simulationTask != nil {
            simulationTask?.cancel()
            simulationTask = nil
            finishAndEmitTranscript()
            return
        }

        if !Self.canUseInProcessSpeechRecognizer {
            logVoice("Posting IPC stop to Speech Worker")
            DistributedNotificationCenter.default().postNotificationName(
                IPCNotification.stop,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            // Wait up to 650ms for Speech Worker to send IPCNotification.finalResult
            finalizationTask?.cancel()
            finalizationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard let self = self, !Task.isCancelled else { return }
                self.finishAndEmitTranscript()
            }
            return
        }

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()

        finalizationTask?.cancel()
        finalizationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self = self, !Task.isCancelled else { return }
            self.finishAndEmitTranscript()
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
        }
    }

    private func finishAndEmitTranscript() {
        guard !hasEmittedFinalForCurrentSession else { return }
        hasEmittedFinalForCurrentSession = true

        let finalClean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalClean.isEmpty {
            lastFinalizedTranscript = finalClean
            statusMessage = "✓ Đã nhận diện: \"\(finalClean)\""
            logVoice("FINAL EMIT text='\(finalClean)'")
            onRecordingStateChanged?(false, statusMessage)
            onFinalTranscript?(finalClean)
        } else {
            statusMessage = "Chưa nhận diện được lời nói (Hãy kiểm tra quyền Speech Recognition hoặc nói rõ hơn)."
            logVoice("FINAL EMIT EMPTY")
            onRecordingStateChanged?(false, statusMessage)
            onFinalTranscript?("")
        }
    }

    // MARK: - LaunchServices Speech Worker IPC

    private func setupMainDaemonIPCObserversIfNeeded() {
        guard !ipcObserversInstalled, !CommandLine.arguments.contains("--speech-worker") else { return }
        ipcObserversInstalled = true

        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: IPCNotification.audioLevel, object: nil, queue: .main) { [weak self] note in
            guard let self = self, self.isRecording else { return }
            if let level = note.userInfo?["audioLevel"] as? Float {
                self.audioLevel = level
                self.onPartialTranscript?(self.transcript, level)
            }
        }
        center.addObserver(forName: IPCNotification.partial, object: nil, queue: .main) { [weak self] note in
            guard let self = self, self.isRecording else { return }
            let text = (note.userInfo?["text"] as? String) ?? ""
            let level = (note.userInfo?["audioLevel"] as? Float) ?? self.audioLevel
            self.audioLevel = level
            if !text.isEmpty {
                self.transcript = text
            }
            self.onPartialTranscript?(self.transcript, level)
        }
        center.addObserver(forName: IPCNotification.finalResult, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let text = note.userInfo?["text"] as? String, !text.isEmpty {
                self.transcript = text
            }
            self.finalizationTask?.cancel()
            self.finishAndEmitTranscript()
        }
        center.addObserver(forName: IPCNotification.workerStatus, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let sAuth = note.userInfo?["speechAuthorized"] as? Bool {
                self.workerAuthorizedSpeech = sAuth
            }
            if let mAuth = note.userInfo?["micAuthorized"] as? Bool {
                self.workerAuthorizedMic = mAuth
            }
            if let status = note.userInfo?["statusMessage"] as? String, !status.isEmpty {
                self.statusMessage = status
                if let rec = note.userInfo?["isRecording"] as? Bool, !rec && self.isRecording {
                    self.isRecording = false
                    self.onRecordingStateChanged?(false, status)
                }
            }
        }
    }

    public static func resolveAppBundlePath() -> String {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main.bundlePath
        }
        if let exec = ProcessInfo.processInfo.arguments.first {
            let execURL = URL(fileURLWithPath: exec)
            let candidate = execURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            if candidate.pathExtension == "app" && FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }
        let localBuildApp = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/VFlow.app").path
        if FileManager.default.fileExists(atPath: localBuildApp) {
            return localBuildApp
        }
        let standardApp = "/Applications/VFlow.app"
        if FileManager.default.fileExists(atPath: standardApp) {
            return standardApp
        }
        let userApp = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/VFlow.app").path
        if FileManager.default.fileExists(atPath: userApp) {
            return userApp
        }
        return standardApp
    }

    public func terminateSpeechWorker() {
        guard let pidStr = try? String(contentsOfFile: Self.workerPidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidStr), pid > 1 else { return }
        kill(pid, SIGTERM)
        try? FileManager.default.removeItem(atPath: Self.workerPidFile)
    }

    private func isSpeechWorkerRunning() -> Bool {
        guard let pidStr = try? String(contentsOfFile: Self.workerPidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidStr),
              pid > 1 else {
            return false
        }
        return kill(pid, 0) == 0
    }

    /// Launches a standalone `VFlow.app` instance with `-n` (`--new`) and `--speech-worker` via `/usr/bin/open`
    /// so `launchd` (`ppid == 1`) is its parent and macOS TCC reads `VFlow.app/Contents/Info.plist`.
    private func ensureSpeechWorkerLaunched(onReady: @escaping @Sendable () -> Void) {
        if isSpeechWorkerRunning() {
            onReady()
            return
        }
        let appBundlePath = Self.resolveAppBundlePath()
        guard FileManager.default.fileExists(atPath: appBundlePath) else {
            onReady()
            return
        }

        logVoice("Spawning new --speech-worker via /usr/bin/open -g -n -a")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-g", "-n", "-a", appBundlePath, "--args", "--speech-worker"]
        try? proc.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onReady()
        }
    }

    private func broadcastWorkerAuthStatus(extraStatus: String? = nil) {
        guard CommandLine.arguments.contains("--speech-worker") else { return }
        let sAuth = (SFSpeechRecognizer.authorizationStatus() == .authorized)
        let mAuth = (AVAudioApplication.shared.recordPermission == .granted)
        var info: [String: Any] = [
            "speechAuthorized": sAuth,
            "micAuthorized": mAuth,
            "isRecording": isRecording
        ]
        if let extraStatus = extraStatus {
            info["statusMessage"] = extraStatus
        }
        DistributedNotificationCenter.default().postNotificationName(
            IPCNotification.workerStatus,
            object: nil,
            userInfo: info,
            deliverImmediately: true
        )
    }

    /// Runs the standalone Speech Worker loop when `VFlow.app` is launched with `--speech-worker`.
    public func startSpeechWorkerServiceMode() {
        let myPid = "\(ProcessInfo.processInfo.processIdentifier)"
        try? myPid.write(toFile: Self.workerPidFile, atomically: true, encoding: .utf8)
        logVoice("Speech Worker started (canUseInProcessSpeechRecognizer=\(Self.canUseInProcessSpeechRecognizer))")

        guard Self.canUseInProcessSpeechRecognizer else { return }
        let center = DistributedNotificationCenter.default()

        onPartialTranscript = { text, level in
            if text.isEmpty {
                center.postNotificationName(
                    IPCNotification.audioLevel,
                    object: nil,
                    userInfo: ["audioLevel": level],
                    deliverImmediately: true
                )
            } else {
                center.postNotificationName(
                    IPCNotification.partial,
                    object: nil,
                    userInfo: ["text": text, "audioLevel": level],
                    deliverImmediately: true
                )
            }
        }
        onFinalTranscript = { text in
            center.postNotificationName(
                IPCNotification.finalResult,
                object: nil,
                userInfo: ["text": text],
                deliverImmediately: true
            )
        }
        onRecordingStateChanged = { [weak self] _, status in
            self?.broadcastWorkerAuthStatus(extraStatus: status)
        }

        broadcastWorkerAuthStatus()

        center.addObserver(forName: IPCNotification.requestAuth, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.requestAuthorization { _ in
                self.broadcastWorkerAuthStatus()
            }
        }
        center.addObserver(forName: IPCNotification.start, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let locale = note.userInfo?["locale"] as? String {
                self.setDictationLanguage(locale)
            }
            self.startStandaloneSpeechRecognition()
        }
        center.addObserver(forName: IPCNotification.stop, object: nil, queue: .main) { [weak self] _ in
            self?.stopRecording()
        }
    }

    /// Computes normalized 0.18 ... 1.0 audio level from an AVAudioPCMBuffer.
    private static func computeNormalizedRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.25 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.22 }

        let samples = channelData[0]
        var sumSquares: Float = 0.0
        let strideStep = max(1, frameLength / 128)
        var count = 0
        var i = 0
        while i < frameLength {
            let s = samples[i]
            sumSquares += s * s
            count += 1
            i += strideStep
        }
        let rms = sqrt(sumSquares / Float(max(1, count)))
        let scaled = min(1.0, max(0.18, rms * 14.0 + 0.18))
        return scaled
    }

    // MARK: - Simulation Mode (Only used when user explicitly toggles Simulation in Settings)

    private func startSimulation() {
        let vnPhrases = [
            "à ừm hôm nay tôi đang thử gõ tiếng việt bằng giọng nói",
            "tôi muốn kiểm tra tiến độ project hôm nay xem đã đạt value chưa",
            "hệ thống hỗ trợ cả tiếng anh và tiếng việt mượt mà"
        ]
        let enPhrases = [
            "uh um i want to test voice to text dictation on macos",
            "can you please review this pull request as soon as possible"
        ]
        let pool = currentLocaleIdentifier.hasPrefix("en") ? enPhrases : vnPhrases
        let selectedPhrase = pool.randomElement() ?? "à ừm hôm nay tôi đang thử gõ tiếng việt bằng giọng nói"
        let words = selectedPhrase.components(separatedBy: " ")

        simulationTask?.cancel()
        simulationTask = Task { @MainActor [weak self] in
            var current = ""
            for word in words {
                guard let self = self, !Task.isCancelled, self.isRecording else { return }
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled, self.isRecording else { return }
                current += (current.isEmpty ? "" : " ") + word
                self.transcript = current
                let level = Float.random(in: 0.45...0.95)
                self.audioLevel = level
                self.onPartialTranscript?(current, level)
            }
            guard let self = self, !Task.isCancelled, self.isRecording else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            self.stopRecordingInternal()
        }
    }
}
