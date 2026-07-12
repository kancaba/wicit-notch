import SwiftUI

struct TimerView: View {
    @ObservedObject private var timer = CountdownTimer.shared
    @ObservedObject private var loc = Localization.shared
    @State private var customMinutes = ""

    private let presets: [(String, Int)] = [
        ("1m", 60), ("5m", 300), ("10m", 600), ("25m", 1500)
    ]
    private let accent = Color.orange

    var body: some View {
        HStack(spacing: 20) {
            dial
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(display)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(timer.isActive ? accent : .white)
                .monospacedDigit()
        }
        .frame(width: 130, height: 130)
    }

    @ViewBuilder
    private var controls: some View {
        if timer.isActive {
            VStack(spacing: 12) {
                controlButton(timer.isRunning ? "pause.fill" : "play.fill", tint: accent) {
                    timer.toggle()
                }
                controlButton("xmark", tint: .white.opacity(0.7)) {
                    timer.cancel()
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("Start a timer", "Sayaç başlat"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { preset in
                        Button {
                            timer.setSeconds(preset.1)
                        } label: {
                            Text(preset.0)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                customDurationRow
            }
        }
    }

    /// Free-form duration: type minutes, press ⏎ or the button.
    @ViewBuilder
    private var customDurationRow: some View {
        HStack(spacing: 8) {
            TextField(loc.t("min", "dk"), text: $customMinutes)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: 52, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .onSubmit(startCustom)
            Text(loc.t("min", "dk"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
            Button(action: startCustom) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.2))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func startCustom() {
        guard let minutes = Int(customMinutes.trimmingCharacters(in: .whitespaces)),
              minutes > 0, minutes <= 24 * 60 else { return }
        customMinutes = ""
        timer.setSeconds(minutes * 60)
    }

    private func controlButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private var display: String {
        let minutes = timer.remaining / 60
        let seconds = timer.remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
