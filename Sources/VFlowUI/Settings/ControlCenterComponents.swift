import SwiftUI
import AppKit

/// Design tokens for the VFlow Liquid Glass Bento Control Center.
public enum VFlowTheme {
    public static let canvasBg = Color(red: 10/255, green: 14/255, blue: 26/255)
    public static let sidebarBg = Color(red: 14/255, green: 20/255, blue: 36/255)
    public static let cardBg = Color(red: 19/255, green: 27/255, blue: 46/255).opacity(0.78)
    public static let cardElevatedBg = Color(red: 26/255, green: 36/255, blue: 60/255).opacity(0.65)
    public static let cyanAccent = Color(red: 56/255, green: 189/255, blue: 248/255)
    public static let purpleAccent = Color(red: 168/255, green: 85/255, blue: 247/255)
    public static let emeraldOk = Color(red: 52/255, green: 211/255, blue: 153/255)
    public static let amberWarn = Color(red: 251/255, green: 191/255, blue: 36/255)
    public static let roseAlert = Color(red: 248/255, green: 113/255, blue: 113/255)
}

/// Compound Bento Card container with header, icon, subtitle, optional trailing accessory, and Liquid Glass border.
public struct ControlBentoCard<Accessory: View, Content: View>: View {
    public let title: String
    public let subtitle: String?
    public let systemIcon: String
    public let accentColor: Color
    public let accessory: Accessory
    public let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        systemIcon: String,
        accentColor: Color = VFlowTheme.cyanAccent,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.accentColor = accentColor
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: systemIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.58))
                    }
                }

                Spacer()
                accessory
            }

            Divider()
                .background(Color.white.opacity(0.08))

            content
        }
        .padding(16)
        .background(
            ZStack {
                VFlowTheme.cardBg
                LinearGradient(
                    colors: [accentColor.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.28), Color.white.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

extension ControlBentoCard where Accessory == EmptyView {
    public init(
        title: String,
        subtitle: String? = nil,
        systemIcon: String,
        accentColor: Color = VFlowTheme.cyanAccent,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            systemIcon: systemIcon,
            accentColor: accentColor,
            accessory: { EmptyView() },
            content: content
        )
    }
}

/// Live telemetry status pill badge with colored dot and label.
public struct ControlStatusPill: View {
    public enum StatusLevel {
        case healthy
        case warning
        case inactive

        var color: Color {
            switch self {
            case .healthy: return VFlowTheme.emeraldOk
            case .warning: return VFlowTheme.amberWarn
            case .inactive: return VFlowTheme.roseAlert
            }
        }
    }

    public let label: String
    public let value: String
    public let level: StatusLevel

    public init(label: String, value: String, level: StatusLevel) {
        self.label = label
        self.value = value
        self.level = level
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.color)
                .frame(width: 7, height: 7)
                .shadow(color: level.color.opacity(0.6), radius: 3)

            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.white.opacity(0.68))

            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(level.color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(level.color.opacity(0.10))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(level.color.opacity(0.28), lineWidth: 1)
        )
    }
}

/// Compact KPI Metric Tile for Dashboard overview.
public struct ControlMetricTile: View {
    public let title: String
    public let value: String
    public let caption: String
    public let systemIcon: String
    public let accentColor: Color

    public init(
        title: String,
        value: String,
        caption: String,
        systemIcon: String,
        accentColor: Color
    ) {
        self.title = title
        self.value = value
        self.caption = caption
        self.systemIcon = systemIcon
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                Spacer()
            }

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(caption)
                .font(.system(size: 10))
                .foregroundColor(accentColor.opacity(0.9))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFlowTheme.cardElevatedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accentColor.opacity(0.22), lineWidth: 1)
        )
    }
}

/// Monospaced keyboard shortcut keycap badge.
public struct KeyboardShortcutCap: View {
    public let keys: String
    public let accent: Color

    public init(_ keys: String, accent: Color = .white) {
        self.keys = keys
        self.accent = accent
    }

    public var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .foregroundColor(accent.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}

/// Custom Liquid Glass Pill Switch that retains its vibrant accent color even inside non-key NSPopover windows.
public struct LiquidGlassSwitch: View {
    @Binding public var isOn: Bool
    public var accentColor: Color

    public init(isOn: Binding<Bool>, accentColor: Color = VFlowTheme.cyanAccent) {
        self._isOn = isOn
        self.accentColor = accentColor
    }

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                isOn.toggle()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(
                        isOn
                            ? LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 34, height: 19)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isOn ? accentColor.opacity(0.6) : Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: isOn ? accentColor.opacity(0.35) : .clear, radius: 4, y: 1)

                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .padding(2)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Công tắc")
        .accessibilityValue(isOn ? "Đang bật" : "Đang tắt")
    }
}

/// Left-aligned, high-contrast Liquid Glass Toggle Row replacing unreadable dark macOS checkboxes.
public struct LiquidGlassToggleRow: View {
    public let title: String
    public let subtitle: String?
    @Binding public var isOn: Bool
    public var accentColor: Color
    public var compact: Bool

    public init(
        _ title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        accentColor: Color = VFlowTheme.cyanAccent,
        compact: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.accentColor = accentColor
        self.compact = compact
    }

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        }) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? accentColor : Color.white.opacity(0.08))
                        .frame(width: compact ? 16 : 18, height: compact ? 16 : 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(isOn ? accentColor : Color.white.opacity(0.28), lineWidth: 1.2)
                        )
                        .shadow(color: isOn ? accentColor.opacity(0.4) : .clear, radius: 3)

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: compact ? 9.5 : 10.5, weight: .heavy))
                            .foregroundColor(Color(red: 8/255, green: 12/255, blue: 22/255))
                    }
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(title)
                        .font(.system(size: compact ? 11.2 : 11.8, weight: isOn ? .semibold : .medium))
                        .foregroundColor(isOn ? .white : .white.opacity(0.75))
                        .lineLimit(1)

                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Đang bật" : "Đang tắt")
    }
}
