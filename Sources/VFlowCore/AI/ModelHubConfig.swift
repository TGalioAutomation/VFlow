import Foundation

/// Status of a local neural model on Apple Silicon.
public enum ModelDownloadStatus: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case error(String)
}

/// Metadata and specifications for an on-device local neural model.
public struct LocalModelInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let sizeFormatted: String
    public let memoryRequirement: String
    public let inferenceSpeed: String
    public var status: ModelDownloadStatus

    public init(
        id: String,
        name: String,
        description: String,
        sizeFormatted: String,
        memoryRequirement: String,
        inferenceSpeed: String,
        status: ModelDownloadStatus = .notDownloaded
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sizeFormatted = sizeFormatted
        self.memoryRequirement = memoryRequirement
        self.inferenceSpeed = inferenceSpeed
        self.status = status
    }
}

/// Hub manager coordinating local models for text polish and voice dictation.
public final class LocalModelHub: @unchecked Sendable {
    public static let shared = LocalModelHub()

    public private(set) var availableModels: [LocalModelInfo]
    public var selectedTextModelId: String = "qwen-1.5b-4bit"

    private let lock = NSLock()

    public init() {
        self.availableModels = [
            LocalModelInfo(
                id: "qwen-1.5b-4bit",
                name: "Qwen2.5-1.5B-Instruct-4bit",
                description: "Mô hình ngôn ngữ siêu nhẹ tối ưu Apple Neural Engine cho nhu cầu sửa câu & tone văn tức thì.",
                sizeFormatted: "980 MB",
                memoryRequirement: "1.2 GB Unified Memory",
                inferenceSpeed: "~45 tokens/s",
                status: .ready // Default ready or local
            ),
            LocalModelInfo(
                id: "qwen-3b-4bit",
                name: "Qwen2.5-3B-Instruct-4bit",
                description: "Mô hình chất lượng cao, viết lại văn bản học thuật và công sở phức tạp với độ trôi chảy tối đa.",
                sizeFormatted: "1.9 GB",
                memoryRequirement: "2.4 GB Unified Memory",
                inferenceSpeed: "~32 tokens/s",
                status: .notDownloaded
            ),
            LocalModelInfo(
                id: "whisper-v3-turbo-coreml",
                name: "Whisper-Large-v3-Turbo-CoreML",
                description: "Bộ nhận diện giọng nói tiếng Việt CoreML ANE tốc độ cao, nhận dạng tức thì mọi âm sắc vùng miền.",
                sizeFormatted: "810 MB",
                memoryRequirement: "1.1 GB Unified Memory",
                inferenceSpeed: "Realtime 0.2x",
                status: .ready
            )
        ]
    }

    /// Triggers download simulation or local asset verification.
    public func startDownload(modelId: String, onProgress: @escaping @Sendable (Double) -> Void, onComplete: @escaping @Sendable (Bool) -> Void) {
        lock.lock()
        guard let index = availableModels.firstIndex(where: { $0.id == modelId }) else {
            lock.unlock()
            onComplete(false)
            return
        }
        availableModels[index].status = .downloading(progress: 0.0)
        lock.unlock()

        Task {
            for step in 1...10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                let progress = Double(step) / 10.0
                await MainActor.run {
                    self.lock.lock()
                    if let idx = self.availableModels.firstIndex(where: { $0.id == modelId }) {
                        self.availableModels[idx].status = .downloading(progress: progress)
                    }
                    self.lock.unlock()
                    onProgress(progress)
                }
            }

            await MainActor.run {
                self.lock.lock()
                if let idx = self.availableModels.firstIndex(where: { $0.id == modelId }) {
                    self.availableModels[idx].status = .ready
                }
                self.lock.unlock()
                onComplete(true)
            }
        }
    }
}
