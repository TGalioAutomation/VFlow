import Foundation
import CoreGraphics
import AppKit

/// Monitors Push-to-Talk & Tap-to-Talk hotkeys (`Option + Space` or `Fn` key hold) globally and locally.
/// Supports both:
/// - **Tap-to-Toggle**: Quick tap (< 350ms) on `⌥Space` starts hands-free recording; tap `⌥Space` again to finish & insert.
/// - **Hold-to-Talk**: Hold `⌥Space` (or `Fn`) while speaking (>= 350ms) and release to finish & insert immediately.
public final class PushToTalkMonitor: @unchecked Sendable {
    public static let shared = PushToTalkMonitor()

    public var onStartRecording: (@Sendable () -> Void)?
    public var onStopRecording: (@Sendable () -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var flagsGlobalMonitor: Any?
    private var flagsLocalMonitor: Any?

    private var isKeyDown: Bool = false
    private var isRecordingActive: Bool = false
    private var stopOnKeyUp: Bool = false
    private var keyDownTimestamp: Date = .distantPast
    private var isFnHeld: Bool = false
    private var fnDownTimestamp: Date = .distantPast
    private let holdThresholdSeconds: TimeInterval = 0.35
    private let lock = NSLock()

    public init() {}

    /// Synchronizes internal active state with `VoiceDictationService.shared.isRecording`.
    public func syncRecordingState(_ active: Bool) {
        lock.withLock {
            isRecordingActive = active
            if !active {
                isKeyDown = false
                stopOnKeyUp = false
            }
        }
    }

    /// Called by `EventTapHook` (or NSEvent monitor) on non-repeating `Option + Space` keyDown.
    public func handleOptionSpaceKeyDown() {
        let action: (@Sendable () -> Void)? = lock.withLock {
            guard !isKeyDown else { return nil }
            isKeyDown = true
            keyDownTimestamp = Date()

            if isRecordingActive {
                // Already recording in hands-free mode -> stop on this press
                stopOnKeyUp = true
                isRecordingActive = false
                return onStopRecording
            } else {
                stopOnKeyUp = false
                isRecordingActive = true
                return onStartRecording
            }
        }
        action?()
    }

    /// Called by `EventTapHook` (or NSEvent monitor) when `Space` is released after `Option + Space`.
    public func handleOptionSpaceKeyUp() {
        let action: (@Sendable () -> Void)? = lock.withLock {
            guard isKeyDown else { return nil }
            isKeyDown = false
            let heldDuration = Date().timeIntervalSince(keyDownTimestamp)

            if stopOnKeyUp {
                stopOnKeyUp = false
                return nil
            }
            // If held >= 350ms, treat as Push-to-Talk hold and stop immediately upon release.
            // If tapped quickly (< 350ms), stay in Hands-Free Recording Mode until next tap!
            if heldDuration >= holdThresholdSeconds && isRecordingActive {
                isRecordingActive = false
                return onStopRecording
            }
            return nil
        }
        action?()
    }

    /// Starts fallback NSEvent monitors (for when CGEventTap is not active or for Fn modifier hold).
    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleNSEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            if self?.handleNSEvent(event) == true {
                return nil
            }
            return event
        }
        flagsGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        flagsLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    @discardableResult
    private func handleNSEvent(_ event: NSEvent) -> Bool {
        // If EventTapHook is active, it already intercepts and swallows Option+Space at the CGEventTap layer
        if EventTapHook.shared.isTapActive {
            return false
        }
        let isSpace = (event.keyCode == KeyCodeMap.kVK_Space)
        let hasOption = event.modifierFlags.contains(.option)

        if isSpace && hasOption && event.type == .keyDown && !event.isARepeat {
            handleOptionSpaceKeyDown()
            return true
        } else if isSpace && event.type == .keyUp {
            handleOptionSpaceKeyUp()
            return true
        }
        return false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Fn key code on macOS is 63 (0x3F)
        guard event.keyCode == 63 else { return }
        let fnPressed = event.modifierFlags.contains(.function)

        let action: (@Sendable () -> Void)? = lock.withLock {
            if fnPressed && !isFnHeld {
                isFnHeld = true
                fnDownTimestamp = Date()
                if !isRecordingActive {
                    isRecordingActive = true
                    return onStartRecording
                }
                return nil
            } else if !fnPressed && isFnHeld {
                isFnHeld = false
                let held = Date().timeIntervalSince(fnDownTimestamp)
                if held >= 0.25 && isRecordingActive {
                    isRecordingActive = false
                    return onStopRecording
                }
                return nil
            }
            return nil
        }
        action?()
    }

    /// Stops monitoring.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = flagsGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            flagsGlobalMonitor = nil
        }
        if let monitor = flagsLocalMonitor {
            NSEvent.removeMonitor(monitor)
            flagsLocalMonitor = nil
        }
    }
}
