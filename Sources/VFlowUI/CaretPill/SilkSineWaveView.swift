import SwiftUI
import VFlowCore

/// Pill HUD operational state.
public enum CaretPillState: String, Equatable, Sendable {
    case transcript
    case working
    case done
}

/// 52x22px 120fps Filled Silk Sine-Wave Canvas with dynamic Severity color palette (Cyan / Amber / Rose).
public struct SilkSineWaveView: View {
    public var state: CaretPillState
    public var audioLevel: Float
    public var severity: SuggestionSeverity

    public init(
        state: CaretPillState = .transcript,
        audioLevel: Float = 0.5,
        severity: SuggestionSeverity = .normal
    ) {
        self.state = state
        self.audioLevel = audioLevel
        self.severity = severity
    }

    private var primaryWaveColor: Color {
        switch severity {
        case .normal:
            return Color(red: 56/255, green: 189/255, blue: 248/255) // Cyan #38BDF8
        case .moderate:
            return Color(red: 251/255, green: 191/255, blue: 36/255) // Amber #FBBF24
        case .high:
            return Color(red: 251/255, green: 113/255, blue: 133/255) // Rose #FB7185
        }
    }

    private var secondaryWaveColor: Color {
        switch severity {
        case .normal:
            return Color(red: 168/255, green: 85/255, blue: 247/255) // Violet #A855F7
        case .moderate:
            return Color(red: 249/255, green: 115/255, blue: 22/255) // Orange #F97316
        case .high:
            return Color(red: 225/255, green: 29/255, blue: 72/255) // Crimson #E11D48
        }
    }

    public var body: some View {
        let primaryColor = primaryWaveColor
        let secondaryColor = secondaryWaveColor

        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let midY = h / 2.0

                // Determine base amplitude and frequency from state
                let targetAmp: CGFloat
                let speed: Double

                switch state {
                case .transcript:
                    let dynamicLevel = CGFloat(max(0.2, min(Double(audioLevel), 1.0)))
                    targetAmp = (h * 0.42) * dynamicLevel
                    speed = severity == .high ? 5.2 : 4.2
                case .working:
                    targetAmp = h * 0.28
                    speed = 2.8
                case .done:
                    targetAmp = h * 0.12
                    speed = 1.0
                }

                // Layer 1: Primary Silk Sine-Wave
                var pathPrimary = Path()
                pathPrimary.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0.0, through: Double(w), by: 1.5) {
                    let relativeX = x / Double(w)
                    let envelope = sin(relativeX * .pi)
                    let y = midY + CGFloat(sin(relativeX * 2.5 * .pi + time * speed) * envelope) * targetAmp
                    pathPrimary.addLine(to: CGPoint(x: x, y: y))
                }
                pathPrimary.addLine(to: CGPoint(x: w, y: h))
                pathPrimary.addLine(to: CGPoint(x: 0, y: h))
                pathPrimary.closeSubpath()

                let primaryGradient = Gradient(colors: [
                    primaryColor.opacity(0.88),
                    primaryColor.opacity(0.16)
                ])
                context.fill(pathPrimary, with: .linearGradient(primaryGradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))

                // Layer 2: Secondary Silk Sine-Wave with phase offset
                var pathSecondary = Path()
                pathSecondary.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0.0, through: Double(w), by: 1.5) {
                    let relativeX = x / Double(w)
                    let envelope = sin(relativeX * .pi)
                    let y = midY + CGFloat(sin(relativeX * 2.5 * .pi + time * (speed * 0.85) + 1.8) * envelope) * (targetAmp * 0.85)
                    pathSecondary.addLine(to: CGPoint(x: x, y: y))
                }
                pathSecondary.addLine(to: CGPoint(x: w, y: h))
                pathSecondary.addLine(to: CGPoint(x: 0, y: h))
                pathSecondary.closeSubpath()

                let secondaryGradient = Gradient(colors: [
                    secondaryColor.opacity(0.76),
                    secondaryColor.opacity(0.12)
                ])
                context.fill(pathSecondary, with: .linearGradient(secondaryGradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
            }
        }
        .frame(width: 52, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(primaryColor.opacity(severity == .normal ? 0.15 : 0.45), lineWidth: 0.6)
        )
    }
}
