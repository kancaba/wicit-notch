import SwiftUI

struct NotchToolbar: View {
    @ObservedObject var state: NotchState
    @ObservedObject private var battery = BatteryService.shared
    @ObservedObject private var caffeine = CaffeineService.shared
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(NotchTab.mainTabs) { tab in
                toolbarButton(for: tab)
            }
            Spacer()
            quickActions
            if let status = battery.status {
                batteryIndicator(status)
            }
            toolbarButton(for: .settings)
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 6) {
            iconButton(symbol: "eyedropper", isActive: false) {
                pickColor()
            }
            .help(loc.t("Pick a color (copies hex)", "Renk seç (hex kopyalanır)"))

            iconButton(symbol: "camera.viewfinder", isActive: false) {
                takeScreenshot()
            }
            .help(loc.t("Screenshot to clipboard", "Ekran görüntüsü panoya"))

            iconButton(symbol: "cup.and.saucer.fill", isActive: caffeine.isActive) {
                caffeine.toggle()
            }
            .help(loc.t("Keep Mac awake", "Mac'i uyanık tut"))
        }
        .padding(.trailing, 4)
    }

    /// System eyedropper — the sampled color lands in the clipboard as hex,
    /// which the clipboard manager then files under Colors.
    private func pickColor() {
        state.requestClose(after: 0)
        NSColorSampler().show { color in
            guard let color = color?.usingColorSpace(.sRGB) else { return }
            let hex = String(
                format: "#%02X%02X%02X",
                Int(color.redComponent * 255),
                Int(color.greenComponent * 255),
                Int(color.blueComponent * 255)
            )
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
        }
    }

    /// Interactive region screenshot straight to the clipboard (and therefore
    /// into clipboard history). Panel closes first so it's out of the shot.
    private func takeScreenshot() {
        state.requestClose(after: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-ic"]
            try? process.run()
        }
    }

    private func batteryIndicator(_ status: BatteryStatus) -> some View {
        HStack(spacing: 4) {
            Text("\(status.percent)%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .monospacedDigit()
            Image(systemName: status.symbol)
                .font(.system(size: 13))
                .foregroundStyle(status.isCharging ? Color.green : .white.opacity(0.75))
        }
        .padding(.trailing, 4)
    }

    private func toolbarButton(for tab: NotchTab) -> some View {
        iconButton(symbol: tab.symbol, isActive: state.selectedTab == tab) {
            state.selectedTab = tab
        }
    }

    private func iconButton(symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.55))
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(Color.white.opacity(isActive ? 0.16 : 0.06))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
