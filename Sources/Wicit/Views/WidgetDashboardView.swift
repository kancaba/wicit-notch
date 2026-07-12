import SwiftUI
import UniformTypeIdentifiers

/// The "home" shelf, matching the reference layout: a single clean row of
/// [Timer (when active)] [Now Playing] [App grid] [Calendar] [Weather].
/// Tiles that have nothing to show step aside and let the others breathe.
struct WidgetDashboardView: View {
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var timer = CountdownTimer.shared
    @ObservedObject private var shortcuts = AppShortcuts.shared

    var body: some View {
        HStack(spacing: NotchLayout.tileSpacing) {
            if timer.isActive {
                TimerTile(timer: timer)
                    .frame(width: 112)
            }

            if let track = nowPlaying.track {
                NowPlayingTile(track: track)
                    .frame(minWidth: 190, maxWidth: .infinity)
            }

            if !shortcuts.apps.isEmpty {
                AppGridTile(shortcuts: shortcuts)
                    .frame(width: 112)
            }

            // Date + weather stacked in one larger column.
            VStack(spacing: NotchLayout.tileSpacing) {
                CalendarTile()
                WeatherTile()
            }
            .frame(width: 168)

            EventsTile()
                .frame(minWidth: 190, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared card chrome

private struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension View {
    func card() -> some View { modifier(Card()) }
}

// MARK: - Timer (compact, only while active)

private struct TimerTile: View {
    @ObservedObject var timer: CountdownTimer
    @ObservedObject private var loc = Localization.shared
    private let accent = Color.orange

    var body: some View {
        VStack(spacing: 8) {
            Text(loc.t("Timer", "Sayaç"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Text(display)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 10) {
                roundButton(timer.isRunning ? "pause.fill" : "play.fill",
                            fill: accent.opacity(0.25), tint: accent) {
                    timer.toggle()
                }
                roundButton("xmark", fill: .white.opacity(0.12), tint: .white) {
                    timer.cancel()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.85), lineWidth: 2)
        )
    }

    private func roundButton(_ symbol: String, fill: Color, tint: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
    }

    private var display: String {
        String(format: "%02d:%02d", timer.remaining / 60, timer.remaining % 60)
    }
}

// MARK: - Now Playing (artwork-filled, reference style)

private struct NowPlayingTile: View {
    let track: NowPlayingTrack
    private var service: NowPlayingService { .shared }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                artwork
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .black.opacity(0.12), location: 0.4),
                        .init(color: .black.opacity(0.78), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        if let icon = track.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                        }
                        Text(track.artist.isEmpty ? track.appName : track.artist)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .shadow(radius: 3)
                    }

                    Spacer(minLength: 0)

                    Text(track.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(radius: 3)

                    // Live streams / some web players report no duration.
                    if track.duration > 0 {
                        progress(at: context.date)
                            .padding(.top, 6)
                    }

                    controls
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(12)
            }
            .card()
        }
    }

    private var artwork: some View {
        GeometryReader { geo in
            Group {
                if let image = track.artwork {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [Color(red: 0.35, green: 0.2, blue: 0.55),
                                            Color(red: 0.1, green: 0.25, blue: 0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.7))
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func progress(at date: Date) -> some View {
        let position = track.position(at: date)
        let fraction = track.duration > 0 ? min(1, position / track.duration) : 0
        return VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.3))
                    Capsule().fill(Color.white)
                        .frame(width: max(2, geo.size.width * fraction))
                }
            }
            .frame(height: 3)

            HStack {
                Text(Self.time(position))
                Spacer()
                Text("-" + Self.time(max(0, track.duration - position)))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .monospacedDigit()
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            controlButton("backward.fill") { service.previous() }
            controlButton(track.isPlaying ? "pause.fill" : "play.fill") { service.playPause() }
            controlButton("forward.fill") { service.next() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private static func time(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - App shortcuts

private struct AppGridTile: View {
    @ObservedObject var shortcuts: AppShortcuts
    @ObservedObject private var loc = Localization.shared
    @State private var hoveringTile = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(shortcuts.apps) { app in
                    AppIconButton(app: app) { shortcuts.launch(app) }
                        .contextMenu {
                            Button(loc.t("Remove", "Kaldır")) {
                                shortcuts.remove(app)
                            }
                            Divider()
                            Button(loc.t("Reset to Dock apps", "Dock uygulamalarına dön")) {
                                shortcuts.resetToDefault()
                            }
                        }
                }
            }
            .padding(10)

            if hoveringTile, shortcuts.apps.count < shortcuts.maxApps {
                Button(action: pickApp) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .padding(5)
                .help(loc.t("Add app", "Uygulama ekle"))
            }
        }
        .card()
        .onHover { hoveringTile = $0 }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        // Agent app + non-activating panel: runModal can leave the dialog
        // buried without focus. Show it non-modally, forced to the front.
        panel.level = .modalPanel
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            if response == .OK, let url = panel.url {
                shortcuts.add(url: url)
            }
        }
        panel.makeKeyAndOrderFront(nil)
    }
}

private struct AppIconButton: View {
    let app: AppShortcut
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 42, height: 42)
                .scaleEffect(hovering ? 1.12 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(app.name)
    }
}

// MARK: - Calendar (date)

private struct CalendarTile: View {
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let date = context.date
            HStack(spacing: 12) {
                Text(format(date, "d"))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text(format(date, "EEE"))
                        .foregroundStyle(Color(red: 0.96, green: 0.26, blue: 0.21))
                    Text(format(date, "MMM"))
                        .foregroundStyle(.white)
                }
                .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .card()
        }
    }

    private func format(_ date: Date, _ template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = loc.locale
        formatter.dateFormat = template
        return formatter.string(from: date)
    }
}

// MARK: - Today's events

private struct EventsTile: View {
    @ObservedObject private var service = EventsService.shared
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.t("Today", "Bugün"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))

            switch service.access {
            case .unknown:
                centered {
                    Button {
                        service.requestAccess()
                    } label: {
                        Text(loc.t("Allow calendar access", "Takvime izin ver"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            case .denied:
                centered {
                    Text(loc.t("Calendar access denied.\nEnable it in System Settings → Privacy.",
                               "Takvim erişimi reddedildi.\nSistem Ayarları → Gizlilik'ten açabilirsin."))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
            case .granted:
                if service.events.isEmpty {
                    centered {
                        Text(loc.t("No more events today 🎉", "Bugün başka etkinlik yok 🎉"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(service.events) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }

    private func centered<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack { Spacer(); HStack { Spacer(); content(); Spacer() }; Spacer() }
    }

    private func eventRow(_ event: DayEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.color))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(time(event.start))–\(time(event.end))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = loc.locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Weather

private struct WeatherTile: View {
    @ObservedObject private var service = WeatherService.shared
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        Group {
            if let weather = service.weather {
                content(weather)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(service.isLoading
                         ? loc.t("Loading…", "Yükleniyor…")
                         : loc.t("Weather unavailable", "Hava durumu alınamadı"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .card()
    }

    /// Compact stacked layout: animated icon + big temperature, then place and
    /// condition beneath.
    private func content(_ weather: WeatherSnapshot) -> some View {
        let description = loc.isTurkish
            ? WeatherService.turkishDescription(code: weather.code)
            : weather.description

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                WeatherIconView(code: weather.code, isDay: weather.isDay, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(weather.temperature)°")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(loc.t("Feels \(weather.feelsLike)°", "Hissedilen \(weather.feelsLike)°"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                if !weather.location.isEmpty {
                    Text(weather.location)
                        .foregroundStyle(.white)
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text(description)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
