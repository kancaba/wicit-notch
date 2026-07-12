import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

/// Compact settings — sized to always fit inside the shelf.
struct SettingsView: View {
    @ObservedObject private var loc = Localization.shared
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var spaces = SpaceMonitor.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var events = EventsService.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(loc.t("Settings", "Ayarlar"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Wicit 0.1.0 · ⌥␣")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }

            row(loc.t("Language", "Dil")) {
                Picker("", selection: $loc.language) {
                    Text(loc.t("System", "Sistem")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("Türkçe").tag(AppLanguage.turkish)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 210)
            }

            row(themeRowTitle) {
                HStack(spacing: 7) {
                    ForEach(NotchTheme.all) { option in
                        themeSwatch(option)
                    }
                }
            }

            row(loc.t("Background image", "Arka plan görseli")) {
                HStack(spacing: 6) {
                    if theme.hasBackgroundImage {
                        smallButton(loc.t("Remove", "Kaldır")) {
                            theme.setBackgroundImage(path: nil)
                        }
                    }
                    smallButton(loc.t("Choose…", "Seç…")) {
                        chooseBackgroundImage()
                    }
                }
            }

            row(loc.t("Weather unit", "Hava birimi")) {
                Picker("", selection: $weather.useFahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 90)
            }

            row(loc.t("Calendar access", "Takvim erişimi")) {
                calendarStatus
            }

            row(loc.t("Launch at login", "Girişte başlat")) {
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, enable in
                        setLaunchAtLogin(enable)
                    }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
    }

    @ViewBuilder
    private var calendarStatus: some View {
        switch events.access {
        case .granted:
            Text(loc.t("Granted ✓", "İzinli ✓"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.green.opacity(0.85))
        case .unknown:
            smallButton(loc.t("Request", "İzin iste")) {
                events.requestAccess()
            }
        case .denied:
            smallButton(loc.t("Open System Settings", "Sistem Ayarları'nı aç")) {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Themes are stored per Space (like the reference design); reflect that in
    /// the label when Space identity is available.
    private var themeRowTitle: String {
        if spaces.isAvailable {
            let space = spaces.spaceIndex + 1
            return loc.t("Theme · Space \(space)", "Tema · Space \(space)")
        }
        return loc.t("Theme", "Tema")
    }

    private func themeSwatch(_ option: NotchTheme) -> some View {
        let isSelected = theme.current == option
        return Button {
            theme.select(option)
        } label: {
            Circle()
                .fill(
                    LinearGradient(colors: [.black, option.bottom],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? Color.white : Color.white.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
                )
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(option.name(loc))
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            content()
        }
        .frame(height: 22)
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Agent app: show non-modally and force to front (see pickApp()).
        panel.level = .modalPanel
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            if response == .OK, let url = panel.url {
                theme.setBackgroundImage(path: url.path)
            }
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert the toggle if the system refused (e.g. unsigned dev build).
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
