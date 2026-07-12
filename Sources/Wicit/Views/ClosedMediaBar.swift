import SwiftUI

/// Mini display in the collapsed strip's wings: album artwork (or a timer glyph)
/// on the left of the notch, and an equalizer or live countdown on the right —
/// echoing the classic notch-app look.
struct ClosedMediaBar: View {
    let track: NowPlayingTrack?
    let notchWidth: CGFloat
    @ObservedObject private var timer = CountdownTimer.shared

    private let accent = Color.orange

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color.clear
                leftContent.padding(.leading, 13)
            }
            .frame(width: NotchLayout.mediaSideWidth)

            // The physical notch — keep it pure black.
            Color.clear.frame(width: notchWidth)

            ZStack(alignment: .trailing) {
                Color.clear
                rightContent.padding(.trailing, 13)
            }
            .frame(width: NotchLayout.mediaSideWidth)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Wings

    @ViewBuilder
    private var leftContent: some View {
        if let track {
            artwork(track)
        } else if timer.isActive {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    @ViewBuilder
    private var rightContent: some View {
        if timer.isActive {
            // Timer takes priority over the equalizer on the right wing.
            Text(countdown)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timer.isRunning ? accent : accent.opacity(0.5))
        } else if let track {
            EqualizerBars(isPlaying: track.isPlaying)
        }
    }

    private var countdown: String {
        String(format: "%02d:%02d", timer.remaining / 60, timer.remaining % 60)
    }

    private func artwork(_ track: NowPlayingTrack) -> some View {
        Group {
            if let image = track.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.purple, .blue],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.85))
                    )
            }
        }
        .frame(width: 21, height: 21)
        .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
    }
}

/// Three softly bouncing bars while playing; calm dots when paused.
private struct EqualizerBars: View {
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2.5, height: height(for: index, time: t))
                }
            }
        }
        .frame(height: 18)
    }

    private func height(for index: Int, time: Double) -> CGFloat {
        guard isPlaying else { return 3.5 }
        let phase = time * 3.4 + Double(index) * 1.3
        return 5 + 10 * abs(sin(phase))
    }
}
