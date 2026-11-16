import Foundation
import CryptoKit
import AppKit

/// Metadata describing an official VFlow GitHub Release fetched from GitHub Releases API.
public struct VFlowReleaseInfo: Equatable, Sendable {
    public let version: String
    public let tagName: String
    public let title: String
    public let releaseNotes: String
    public let zipAssetName: String
    public let zipDownloadURL: URL
    public let checksumsDownloadURL: URL?
    public let htmlURL: URL?
    public let publishedAt: String?

    public init(
        version: String,
        tagName: String,
        title: String,
        releaseNotes: String,
        zipAssetName: String,
        zipDownloadURL: URL,
        checksumsDownloadURL: URL? = nil,
        htmlURL: URL? = nil,
        publishedAt: String? = nil
    ) {
        self.version = version
        self.tagName = tagName
        self.title = title
        self.releaseNotes = releaseNotes
        self.zipAssetName = zipAssetName
        self.zipDownloadURL = zipDownloadURL
        self.checksumsDownloadURL = checksumsDownloadURL
        self.htmlURL = htmlURL
        self.publishedAt = publishedAt
    }
}

/// Lifecycle state for built-in VFlow auto-update checks and self-installation.
public enum VFlowUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case available(VFlowReleaseInfo)
    case downloading(progress: Double)
    case verifying
    case installing(version: String)
    case failed(String)

    public var statusDescription: String {
        switch self {
        case .idle:
            return "Sẵn sàng kiểm tra bản cập nhật"
        case .checking:
            return "Đang kiểm tra bản phát hành mới trên GitHub..."
        case .upToDate(let current):
            return "Đang dùng phiên bản mới nhất (v\(current))"
        case .available(let release):
            return "Có bản cập nhật mới: \(release.tagName)"
        case .downloading(let progress):
            return String(format: "Đang tải bản cập nhật... %.0f%%", max(0, min(100, progress * 100)))
        case .verifying:
            return "Đang kiểm tra chữ ký số & mã băm SHA-256..."
        case .installing(let version):
            return "Đang nâng cấp lên v\(version) và khởi động lại..."
        case .failed(let message):
            return "Lỗi cập nhật: \(message)"
        }
    }
}

public enum VFlowUpdaterError: LocalizedError, Equatable {
    case invalidResponse
    case noInstallableArchiveFound
    case checksumMismatch(expected: String, actual: String)
    case extractedBundleNotFound
    case invalidCodeSignature(String)
    case bundleIdentifierMismatch(String)
    case scriptLaunchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Phản hồi từ GitHub Releases API không hợp lệ."
        case .noInstallableArchiveFound:
            return "Không tìm thấy tệp cài đặt .zip macOS trong bản phát hành."
        case .checksumMismatch(let expected, let actual):
            return "Mã băm SHA-256 không khớp (kỳ vọng \(expected.prefix(12))..., nhận \(actual.prefix(12))...)."
        case .extractedBundleNotFound:
            return "Không tìm thấy VFlow.app sau khi giải nén."
        case .invalidCodeSignature(let detail):
            return "Kiểm tra chữ ký ứng dụng thất bại: \(detail)"
        case .bundleIdentifierMismatch(let found):
            return "Bundle Identifier không khớp (\(found))."
        case .scriptLaunchFailed(let detail):
            return "Không thể chạy trình cài đặt nâng cấp: \(detail)"
        }
    }
}

/// Native GitHub Releases auto-checker & SHA-256 verified atomic self-updater for VFlow.
public final class VFlowUpdater: @unchecked Sendable {
    public static let shared = VFlowUpdater()

    public static let defaultLatestReleaseAPIURL = URL(string: "https://api.github.com/repos/TGalioAutomation/VFlow/releases/latest")!

    private let apiURL: URL
    private let lock = NSLock()
    private var isOperationInFlight = false

    public init(apiURL: URL = VFlowUpdater.defaultLatestReleaseAPIURL) {
        self.apiURL = apiURL
    }

    /// Returns the running bundle's marketing version (fallback `"1.0.2"` when executed from SwiftPM debug binaries).
    public static var currentAppVersion: String {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !ver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalizeVersionString(ver)
        }
        return "1.0.2"
    }

    /// Strips leading `v`/`V` and build metadata from version strings (e.g. `"v1.0.2"` -> `"1.0.2"`).
    public static func normalizeVersionString(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        if let plusIdx = trimmed.firstIndex(of: "+") {
            trimmed = String(trimmed[..<plusIdx])
        }
        return trimmed
    }

    /// Compares two semantic version strings (`"1.0.2"` vs `"1.0.1"`, optionally prefixed with `v`).
    /// Returns `.orderedDescending` when `lhs > rhs`, `.orderedAscending` when `lhs < rhs`, `.orderedSame` when equal.
    public static func compareSemVer(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let normA = normalizeVersionString(lhs)
        let normB = normalizeVersionString(rhs)

        let splitA = normA.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let splitB = normB.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)

        let numsA = (splitA.first ?? "").split(separator: ".").map { Int($0) ?? 0 }
        let numsB = (splitB.first ?? "").split(separator: ".").map { Int($0) ?? 0 }

        let count = max(numsA.count, numsB.count, 3)
        for i in 0..<count {
            let va = i < numsA.count ? numsA[i] : 0
            let vb = i < numsB.count ? numsB[i] : 0
            if va > vb { return .orderedDescending }
            if va < vb { return .orderedAscending }
        }

        let preA = splitA.count > 1 ? String(splitA[1]) : nil
        let preB = splitB.count > 1 ? String(splitB[1]) : nil
        switch (preA, preB) {
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedDescending // Stable release > pre-release
        case (_, nil):
            return .orderedAscending
        case (let a?, let b?):
            return a.compare(b, options: .numeric)
        }
    }

    /// Parses GitHub `/releases/latest` JSON payload into `VFlowReleaseInfo`.
    public static func parseGitHubReleaseJSON(_ data: Data) throws -> VFlowReleaseInfo {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            throw VFlowUpdaterError.invalidResponse
        }

        let version = normalizeVersionString(tagName)
        let title = (json["name"] as? String) ?? tagName
        let notes = (json["body"] as? String) ?? ""
        let htmlURL = (json["html_url"] as? String).flatMap(URL.init(string:))
        let publishedAt = json["published_at"] as? String

        var bestZipName: String?
        var bestZipURL: URL?
        var checksumsURL: URL?

        for asset in assets {
            guard let name = asset["name"] as? String,
                  let downloadStr = asset["browser_download_url"] as? String,
                  let url = URL(string: downloadStr) else {
                continue
            }
            let lower = name.lowercased()
            if lower == "sha256sums.txt" || lower.contains("sha256") {
                checksumsURL = url
            } else if lower.hasSuffix(".zip") {
                // Prefer arm64/macOS archive when multiple zips exist
                if bestZipURL == nil || lower.contains("arm64") || lower.contains("macos") {
                    bestZipName = name
                    bestZipURL = url
                }
            }
        }

        guard let zipName = bestZipName, let zipURL = bestZipURL else {
            throw VFlowUpdaterError.noInstallableArchiveFound
        }

        return VFlowReleaseInfo(
            version: version,
            tagName: tagName,
            title: title,
            releaseNotes: notes,
            zipAssetName: zipName,
            zipDownloadURL: zipURL,
            checksumsDownloadURL: checksumsURL,
            htmlURL: htmlURL,
            publishedAt: publishedAt
        )
    }

    /// Parses a `SHA256SUMS.txt` file and returns the lowercase 64-char hex digest matching `fileName`.
    public static func extractExpectedSHA256(forFileName fileName: String, from checksumsText: String) -> String? {
        let lines = checksumsText.components(separatedBy: .newlines)
        let targetBase = URL(fileURLWithPath: fileName).lastPathComponent.lowercased()

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else { continue }

            let hashCandidate = String(parts[0]).lowercased()
            guard hashCandidate.count == 64,
                  hashCandidate.allSatisfy({ $0.isHexDigit }) else {
                continue
            }

            let entryNameRaw = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "*"))
            let entryBase = URL(fileURLWithPath: entryNameRaw).lastPathComponent.lowercased()
            if entryBase == targetBase {
                return hashCandidate
            }
        }
        return nil
    }

    /// Computes lowercase SHA-256 hex digest of a local file using streaming reads.
    public static func sha256Hex(of fileURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 65536)
            if chunk.isEmpty {
                return false
            }
            hasher.update(data: chunk)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Resolves the target `.app` installation path (currently running `.app` if in `/Applications`, otherwise `/Applications/VFlow.app` or current `.app`).
    public static func resolveInstallTargetPath() -> String {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            return bundleURL.path
        }
        return "/Applications/VFlow.app"
    }

    /// Checks GitHub Releases API for a newer version than `currentVersion`.
    public func checkLatestRelease(currentVersion: String = VFlowUpdater.currentAppVersion) async -> VFlowUpdateState {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("VFlow/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode) else {
                return .failed("Máy chủ GitHub trả về lỗi HTTP.")
            }
            let release = try Self.parseGitHubReleaseJSON(data)
            if Self.compareSemVer(release.version, currentVersion) == .orderedDescending {
                EventTapHook.shared.logDiagnostic("UPDATER_AVAILABLE current=\(currentVersion) latest=\(release.version)")
                return .available(release)
            } else {
                return .upToDate(currentVersion: currentVersion)
            }
        } catch let err as VFlowUpdaterError {
            return .failed(err.localizedDescription)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Downloads, verifies SHA-256 + codesign, replaces the `.app` bundle atomically, and relaunches the updated VFlow daemon.
    public func downloadAndInstall(
        release: VFlowReleaseInfo,
        targetAppPath: String = VFlowUpdater.resolveInstallTargetPath(),
        onStateChange: @escaping @Sendable (VFlowUpdateState) -> Void
    ) async {
        let canStart = lock.withLock { () -> Bool in
            guard !isOperationInFlight else { return false }
            isOperationInFlight = true
            return true
        }
        guard canStart else { return }
        defer {
            lock.withLock { isOperationInFlight = false }
        }

        let fileManager = FileManager.default
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("vflow_update_\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            let zipURL = stagingDir.appendingPathComponent(release.zipAssetName)
            let extractDir = stagingDir.appendingPathComponent("extracted", isDirectory: true)
            try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

            onStateChange(.downloading(progress: 0.1))

            var zipReq = URLRequest(url: release.zipDownloadURL)
            zipReq.setValue("VFlow/\(Self.currentAppVersion)", forHTTPHeaderField: "User-Agent")
            zipReq.timeoutInterval = 60.0

            let (tempDownloadedURL, zipResp) = try await URLSession.shared.download(for: zipReq)
            guard let httpResp = zipResp as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode) else {
                throw VFlowUpdaterError.invalidResponse
            }
            if fileManager.fileExists(atPath: zipURL.path) {
                try fileManager.removeItem(at: zipURL)
            }
            try fileManager.moveItem(at: tempDownloadedURL, to: zipURL)
            onStateChange(.downloading(progress: 1.0))

            onStateChange(.verifying)

            // 1. Verify SHA-256 against SHA256SUMS.txt if present
            if let checksumURL = release.checksumsDownloadURL {
                var sumReq = URLRequest(url: checksumURL)
                sumReq.setValue("VFlow/\(Self.currentAppVersion)", forHTTPHeaderField: "User-Agent")
                sumReq.timeoutInterval = 15.0
                let (sumData, sumResp) = try await URLSession.shared.data(for: sumReq)
                if let httpSum = sumResp as? HTTPURLResponse, (200..<300).contains(httpSum.statusCode),
                   let sumsText = String(data: sumData, encoding: .utf8),
                   let expectedHash = Self.extractExpectedSHA256(forFileName: release.zipAssetName, from: sumsText) {
                    let actualHash = Self.sha256Hex(of: zipURL) ?? ""
                    if actualHash != expectedHash {
                        throw VFlowUpdaterError.checksumMismatch(expected: expectedHash, actual: actualHash)
                    }
                }
            }

            // 2. Extract archive preserving macOS resource forks & symlinks
            let dittoResult = Self.runCommandSync("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, extractDir.path])
            guard dittoResult.status == 0 else {
                throw VFlowUpdaterError.extractedBundleNotFound
            }

            guard let newAppURL = Self.findAppBundle(in: extractDir) else {
                throw VFlowUpdaterError.extractedBundleNotFound
            }

            // 3. Verify bundle identifier & strict code signature
            if let bundle = Bundle(url: newAppURL),
               let bundleId = bundle.bundleIdentifier,
               bundleId != "com.apexdev.vflow" {
                throw VFlowUpdaterError.bundleIdentifierMismatch(bundleId)
            }
            let signCheck = Self.runCommandSync("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", newAppURL.path])
            guard signCheck.status == 0 else {
                throw VFlowUpdaterError.invalidCodeSignature(signCheck.output)
            }

            onStateChange(.installing(version: release.version))
            EventTapHook.shared.logDiagnostic("UPDATER_INSTALLING version=\(release.version) target=\(targetAppPath)")

            // 4. Launch detached shell script to swap the .app cleanly after current process terminates and reopen it
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let scriptURL = stagingDir.appendingPathComponent("apply_update.sh")
            let scriptBody = """
            #!/usr/bin/env bash
            set -euo pipefail
            OLD_PID="$1"
            NEW_APP="$2"
            TARGET_APP="$3"
            STAGING_DIR="$4"

            for _ in $(seq 1 40); do
                if ! kill -0 "$OLD_PID" 2>/dev/null; then
                    break
                fi
                sleep 0.25
            done

            if [ -f /tmp/vflow_speech_worker.pid ]; then
                W_PID="$(cat /tmp/vflow_speech_worker.pid 2>/dev/null || true)"
                if [ -n "$W_PID" ]; then
                    kill "$W_PID" 2>/dev/null || true
                fi
                rm -f /tmp/vflow_speech_worker.pid
            fi

            BACKUP_APP="${TARGET_APP}.backup"
            rm -rf "$BACKUP_APP"
            if [ -d "$TARGET_APP" ]; then
                mv "$TARGET_APP" "$BACKUP_APP"
            fi

            if ditto "$NEW_APP" "$TARGET_APP"; then
                rm -rf "$BACKUP_APP"
            else
                if [ -d "$BACKUP_APP" ]; then
                    rm -rf "$TARGET_APP"
                    mv "$BACKUP_APP" "$TARGET_APP"
                fi
                exit 1
            fi

            # Also mirror update to /Applications/VFlow.app if user launched from build/VFlow.app
            if [ "$TARGET_APP" != "/Applications/VFlow.app" ] && [ -d "/Applications/VFlow.app" ]; then
                rm -rf "/Applications/VFlow.app.backup"
                mv "/Applications/VFlow.app" "/Applications/VFlow.app.backup" || true
                if ditto "$NEW_APP" "/Applications/VFlow.app"; then
                    rm -rf "/Applications/VFlow.app.backup"
                else
                    mv "/Applications/VFlow.app.backup" "/Applications/VFlow.app" || true
                fi
            fi

            rm -rf "$STAGING_DIR"
            /usr/bin/open -a "$TARGET_APP" --args --show-settings
            """

            try scriptBody.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let installer = Process()
            installer.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            installer.arguments = [scriptURL.path, "\(currentPID)", newAppURL.path, targetAppPath, stagingDir.path]
            installer.standardInput = FileHandle.nullDevice
            installer.standardOutput = FileHandle.nullDevice
            installer.standardError = FileHandle.nullDevice
            try installer.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NSApp.terminate(nil)
            }
        } catch let err as VFlowUpdaterError {
            try? fileManager.removeItem(at: stagingDir)
            onStateChange(.failed(err.localizedDescription))
        } catch {
            try? fileManager.removeItem(at: stagingDir)
            onStateChange(.failed(error.localizedDescription))
        }
    }

    private static func findAppBundle(in directory: URL) -> URL? {
        let direct = directory.appendingPathComponent("VFlow.app")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent == "VFlow.app" {
                return url
            }
        }
        return nil
    }

    private static func runCommandSync(_ path: String, arguments: [String]) -> (status: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = outPipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let outStr = String(data: data, encoding: .utf8) ?? ""
            return (proc.terminationStatus, outStr)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
