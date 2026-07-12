import SwiftUI

/// Animated weather icon composed from SF Symbol bases + animated overlays:
/// rotating sun rays, drifting clouds, falling rain/snow, flashing lightning.
struct WeatherIconView: View {
    let code: Int
    let isDay: Bool
    var size: CGFloat = 40

    private enum Kind {
        case sun, moon, partlyDay, partlyNight, cloud, fog, rain, snow, thunder
    }

    private var kind: Kind {
        switch code {
        case 0: return isDay ? .sun : .moon
        case 1, 2: return isDay ? .partlyDay : .partlyNight
        case 3: return .cloud
        case 45, 48: return .fog
        case 51...67, 80...82: return .rain
        case 71...77, 85, 86: return .snow
        case 95, 96, 99: return .thunder
        default: return .cloud
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            canvas(time: t)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func canvas(time t: Double) -> some View {
        switch kind {
        case .sun:
            Image(systemName: "sun.max.fill")
                .font(.system(size: size * 0.8))
                .foregroundStyle(.yellow)
                .rotationEffect(.radians(t * 0.35))

        case .moon:
            ZStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: size * 0.72))
                    .foregroundStyle(Color(red: 0.85, green: 0.87, blue: 1))
                star(x: 0.72, y: 0.2, phase: t * 1.6)
                star(x: 0.88, y: 0.48, phase: t * 1.6 + 2.1)
            }

        case .partlyDay, .partlyNight:
            ZStack {
                Image(systemName: kind == .partlyDay ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(kind == .partlyDay ? .yellow : Color(red: 0.85, green: 0.87, blue: 1))
                    .offset(x: -size * 0.18, y: -size * 0.18)
                    .rotationEffect(kind == .partlyDay ? .radians(t * 0.35) : .zero)
                drifting(cloudSize: size * 0.62, time: t, amplitude: size * 0.06)
                    .offset(x: size * 0.1, y: size * 0.14)
            }

        case .cloud:
            drifting(cloudSize: size * 0.8, time: t, amplitude: size * 0.07)

        case .fog:
            VStack(spacing: size * 0.12) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(.white.opacity(0.85))
                fogLine(width: size * 0.7, shift: sin(t * 1.2) * size * 0.08)
                fogLine(width: size * 0.55, shift: sin(t * 1.2 + .pi) * size * 0.08)
            }

        case .rain:
            precipitation(time: t) { phase in
                Capsule()
                    .fill(Color(red: 0.45, green: 0.7, blue: 1))
                    .frame(width: size * 0.05, height: size * 0.16)
                    .opacity(1 - phase)
            }

        case .snow:
            precipitation(time: t, speed: 0.6) { phase in
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .opacity(1 - phase)
            }

        case .thunder:
            ZStack(alignment: .bottom) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: size * 0.75))
                    .foregroundStyle(.white.opacity(0.9))
                    .offset(y: -size * 0.12)
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.yellow)
                    .offset(y: size * 0.16)
                    // Irregular flash: bright pulse twice per ~1.6s cycle.
                    .opacity(flash(t))
            }
        }
    }

    // MARK: - Pieces

    private func drifting(cloudSize: CGFloat, time t: Double, amplitude: CGFloat) -> some View {
        Image(systemName: "cloud.fill")
            .font(.system(size: cloudSize))
            .foregroundStyle(.white.opacity(0.9))
            .offset(x: CGFloat(sin(t * 0.7)) * amplitude)
    }

    private func star(x: CGFloat, y: CGFloat, phase: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * 0.16))
            .foregroundStyle(.white)
            .opacity(0.35 + 0.65 * abs(sin(phase)))
            .position(x: size * x, y: size * y)
    }

    private func fogLine(width: CGFloat, shift: CGFloat) -> some View {
        Capsule()
            .fill(.white.opacity(0.55))
            .frame(width: width, height: size * 0.07)
            .offset(x: shift)
    }

    /// Cloud with looping falling particles beneath it.
    private func precipitation<Drop: View>(
        time t: Double,
        speed: Double = 1.0,
        @ViewBuilder drop: @escaping (Double) -> Drop
    ) -> some View {
        ZStack(alignment: .top) {
            ForEach(0..<3, id: \.self) { index in
                let phase = ((t * speed) + Double(index) * 0.33).truncatingRemainder(dividingBy: 1)
                drop(phase)
                    .offset(
                        x: (CGFloat(index) - 1) * size * 0.2 + (index == 1 ? size * 0.04 : 0),
                        y: size * 0.42 + CGFloat(phase) * size * 0.38
                    )
            }
            Image(systemName: "cloud.fill")
                .font(.system(size: size * 0.72))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func flash(_ t: Double) -> Double {
        let cycle = t.truncatingRemainder(dividingBy: 1.6)
        if cycle < 0.12 || (cycle > 0.28 && cycle < 0.36) { return 1 }
        return 0.45
    }
}
