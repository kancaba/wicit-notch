import SwiftUI

// MARK: - Notch tab: script editor + controls

struct PrompterView: View {
    @ObservedObject private var prompter = Prompter.shared
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        HStack(spacing: 12) {
            editor
            controls
                .frame(width: 190)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $prompter.text)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(8)

            if prompter.text.isEmpty {
                Text(loc.t("Paste or write your script here…", "Metnini buraya yaz veya yapıştır…"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 16)
                    .padding(.leading, 13)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.t("Prompter", "Prompter"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            slider(
                label: loc.t("Speed", "Hız"),
                value: Binding(
                    get: { prompter.speed },
                    set: { prompter.setSpeed($0) }
                ),
                range: 5...200,
                display: "\(Int(prompter.speed)) pt/s"
            )

            slider(
                label: loc.t("Text size", "Yazı boyutu"),
                value: $prompter.fontSize,
                range: 14...60,
                display: "\(Int(prompter.fontSize)) pt"
            )

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(action: start) {
                    Label(loc.t("Start", "Başlat"), systemImage: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
                .disabled(prompter.text.isEmpty)
                .opacity(prompter.text.isEmpty ? 0.4 : 1)

                if prompter.isWindowOpen {
                    Button(action: prompter.closeWindow) {
                        Text(loc.t("Close", "Kapat"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func start() {
        prompter.openWindow(startPlaying: true)
    }

    private func slider(label: String, value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(display)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .controlSize(.mini)
        }
    }
}

// MARK: - Floating window content

struct PrompterWindowView: View {
    @ObservedObject var prompter: Prompter
    @State private var textHeight: CGFloat = 0
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.92))

                scroller(viewport: geo.size)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Readability fades top & bottom.
                VStack {
                    LinearGradient(colors: [.black.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 34)
                    Spacer()
                    LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 34)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

                if hovering {
                    controls
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }
            }
        }
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) { hovering = inside }
        }
    }

    private func scroller(viewport: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let rawOffset = prompter.offset(at: context.date)
            // Stop once the text has fully scrolled past.
            let maxOffset = Double(textHeight) + Double(viewport.height)
            let offset = min(rawOffset, maxOffset)

            Text(prompter.text)
                .font(.system(size: prompter.fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(prompter.fontSize * 0.3)
                .frame(width: viewport.width - 48)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear { textHeight = textGeo.size.height }
                            .onChange(of: textGeo.size.height) { _, h in textHeight = h }
                    }
                )
                .offset(y: viewport.height - CGFloat(offset))
                .frame(width: viewport.width, height: viewport.height, alignment: .top)
                .onChange(of: rawOffset >= maxOffset && textHeight > 0) { _, finished in
                    if finished { prompter.pause() }
                }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            controlButton(prompter.isRunning ? "pause.fill" : "play.fill") {
                prompter.togglePlayback()
            }
            controlButton("backward.end.fill") {
                prompter.restart()
            }

            Slider(
                value: Binding(
                    get: { prompter.speed },
                    set: { prompter.setSpeed($0) }
                ),
                in: 5...200
            )
            .controlSize(.mini)
            .frame(width: 110)

            controlButton("xmark") {
                prompter.closeWindow()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
