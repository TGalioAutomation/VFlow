import AppKit
import SwiftUI
import VFlowCore
import VFlowPlatform

/// Coordinates the Menu Bar icon and quick Control Center popover.
@MainActor
public final class MenuBarCoordinator: NSObject {
    public static let shared = MenuBarCoordinator()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    public var onOpenSettings: (() -> Void)?
    public var onToggleHUDPreview: (() -> Void)?
    public var onQuit: (() -> Void)?

    public var inputMethod: InputMethod = .telex {
        didSet {
            VFlowControlCenterStore.shared.syncInputMethodFromExternal(inputMethod)
            updateStatusItemBadge()
        }
    }
    public var currentTone: PolishTone = .natural
    public var tonePlacement: TonePlacement = .modern

    override public init() {
        super.init()
    }

    /// Sets up the Menu Bar status item and popover.
    public func setup() {
        if self.statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.imagePosition = .imageOnly
                button.target = self
                button.action = #selector(statusBarButtonClicked)
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            self.statusItem = item
        }
        syncFromStore()

        let pop = NSPopover()
        pop.behavior = .transient
        pop.appearance = NSAppearance(named: .darkAqua)
        pop.contentSize = NSSize(width: 310, height: 425)
        self.popover = pop
    }

    public func syncFromStore() {
        let store = VFlowControlCenterStore.shared
        if self.inputMethod != store.inputMethod {
            self.inputMethod = store.inputMethod
        }
        self.currentTone = store.currentTone
        self.tonePlacement = store.tonePlacement
        updateStatusItemBadge()
    }

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button, let pop = popover else { return }

        // Right-click or Option-click quickly toggles VI ⇄ EN
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            let store = VFlowControlCenterStore.shared
            store.inputMethod = (store.inputMethod == .off) ? .telex : .off
            updateStatusItemBadge()
            return
        }

        if pop.isShown {
            pop.performClose(nil)
        } else {
            VFlowControlCenterStore.shared.refreshTelemetry()
            let menuView = BentoMenuView(
                onOpenSettings: { [weak self] in
                    self?.popover?.performClose(nil)
                    BentoSettingsWindowController.shared.showWindow(selecting: .dashboard)
                },
                onOpenMacros: { [weak self] in
                    self?.popover?.performClose(nil)
                    BentoSettingsWindowController.shared.showWindow(selecting: .inputAndMacros)
                },
                onToggleHUDPreview: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onToggleHUDPreview?()
                },
                onQuit: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.onQuit?()
                }
            )

            pop.contentViewController = NSHostingController(rootView: menuView)
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    public func updateStatusItemBadge() {
        guard let button = statusItem?.button else { return }
        let method = VFlowControlCenterStore.shared.inputMethod
        button.title = ""
        button.image = Self.renderMenuBarBadgeImage(for: method)
        button.toolTip = "VFlow (\(method.displayName)) — Click mở bảng điều khiển, Chuột phải/⌥Click chuyển nhanh VI ⇄ EN"
    }

    /// Renders a crisp Retina Liquid Glass capsule badge for the macOS Menu Bar (e.g. `[V̂ VI·T]`, `[V̂ VI·V]`, or `[V EN]`).
    public static func renderMenuBarBadgeImage(for method: InputMethod) -> NSImage {
        let isVN = (method != .off)
        let labelText: String = {
            switch method {
            case .telex: return "VI·T"
            case .vni: return "VI·V"
            case .off: return "EN"
            }
        }()

        let badgeWidth: CGFloat = isVN ? 52.0 : 40.0
        let badgeHeight: CGFloat = 18.0
        let size = NSSize(width: badgeWidth, height: badgeHeight)

        let image = NSImage(size: size, flipped: false) { rect in
            let pillRect = rect.insetBy(dx: 0.75, dy: 0.75)
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 5.5, yRadius: 5.5)

            if isVN {
                NSColor(calibratedRed: 0.04, green: 0.52, blue: 0.68, alpha: 0.32).setFill()
                pillPath.fill()
                NSColor(calibratedRed: 0.0, green: 0.90, blue: 1.0, alpha: 0.85).setStroke()
            } else {
                NSColor(calibratedWhite: 1.0, alpha: 0.10).setFill()
                pillPath.fill()
                NSColor(calibratedWhite: 1.0, alpha: 0.38).setStroke()
            }
            pillPath.lineWidth = 1.1
            pillPath.stroke()

            // Status / Monogram dot on left
            let dotRect = NSRect(x: 5.5, y: (badgeHeight - 5.5) / 2.0, width: 5.5, height: 5.5)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            if isVN {
                NSColor(calibratedRed: 0.0, green: 0.92, blue: 1.0, alpha: 1.0).setFill()
            } else {
                NSColor(calibratedWhite: 0.75, alpha: 0.85).setFill()
            }
            dotPath.fill()

            // Crisp monospaced rounded label
            let font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
            let textColor = isVN
                ? NSColor.white
                : NSColor(calibratedWhite: 0.88, alpha: 0.95)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .kern: -0.2
            ]
            let attrStr = NSAttributedString(string: labelText, attributes: attrs)
            let textSize = attrStr.size()
            let textX = 14.0 + max(0, (badgeWidth - 16.5 - textSize.width) / 2.0)
            let textY = (badgeHeight - textSize.height) / 2.0
            attrStr.draw(at: NSPoint(x: textX, y: textY))
            return true
        }
        image.isTemplate = false
        return image
    }
}
