import SwiftUI

/// Pill HUD operational state.
public enum CaretPillState: String, Equatable, Sendable {
    case transcript
    case working
    case done
}

/// 52x22px 120fps Filled Silk Sine-Wave Canvas (Cyan & Violet dual-layer).
public struct SilkSineWaveView: View {
    public var state: CaretPillState
    public var audioLevel: Float

    public init(state: CaretPillState = .transcript, audioLevel: Float = 0.5) {
        self.state = state
        self.audioLevel = audioLevel
    }

    public var body: some View {
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
                    speed = 4.2
                case .working:
                    targetAmp = h * 0.28
                    speed = 2.8
                case .done:
                    targetAmp = h * 0.12
                    speed = 1.0
                }

                // Layer 1: Cyan Silk Sine-Wave (#38BDF8)
                var pathCyan = Path()
                pathCyan.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0.0, through: Double(w), by: 1.5) {
                    let relativeX = x / Double(w)
                    // Envelope factor: soft taper at both ends
                    let envelope = sin(relativeX * .pi)
                    let y = midY + CGFloat(sin(relativeX * 2.5 * .pi + time * speed) * envelope) * targetAmp
                    pathCyan.addLine(to: CGPoint(x: x, y: y))
                }
                pathCyan.addLine(to: CGPoint(x: w, y: h))
                pathCyan.addLine(to: CGPoint(x: 0, y: h))
                pathCyan.closeSubpath()

                let cyanGradient = Gradient(colors: [
                    Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.85),
                    Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.15)
                ])
                context.fill(pathCyan, with: .linearGradient(cyanGradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))

                // Layer 2: Violet Silk Sine-Wave (#A855F7) with phase offset
                var pathViolet = Path()
                pathViolet.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0.0, through: Double(w), by: 1.5) {
                    let relativeX = x / Double(w)
                    let envelope = sin(relativeX * .pi)
                    let y = midY + CGFloat(sin(relativeX * 2.5 * .pi + time * (speed * 0.85) + 1.8) * envelope) * (targetAmp * 0.85)
                    pathViolet.addLine(to: CGPoint(x: x, y: y))
                }
                pathViolet.addLine(to: CGPoint(x: w, y: h))
                pathViolet.addLine(to: CGPoint(x: 0, y: h))
                pathViolet.closeSubpath()

                let violetGradient = Gradient(colors: [
                    Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.75),
                    Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.10)
                ])
                context.fill(pathViolet, with: .linearGradient(violetGradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
            }
        }
        .frame(width: 52, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}
