import AppKit
import Combine
import UserNotifications

/// A simple countdown timer backing the Timer tab.
final class CountdownTimer: ObservableObject {
    static let shared = CountdownTimer()

    @Published private(set) var remaining: Int = 0
    @Published private(set) var total: Int = 0
    @Published private(set) var isRunning: Bool = false

    private var timer: Timer?

    var isActive: Bool { remaining > 0 || isRunning }

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(total - remaining) / Double(total)
    }

    func setSeconds(_ seconds: Int) {
        remaining = seconds
        total = seconds
        requestNotificationPermissionIfNeeded()
        start()
    }

    func start() {
        guard remaining > 0 else { return }
        isRunning = true
        schedule()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func cancel() {
        pause()
        remaining = 0
        total = 0
    }

    private func schedule() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard isRunning else { return }
        if remaining > 1 {
            remaining -= 1
        } else {
            let elapsed = total
            remaining = 0
            pause()
            total = 0
            NSSound(named: "Glass")?.play()
            postCompletionNotification(totalSeconds: elapsed)
        }
    }

    // MARK: - Completion notification

    private var didRequestNotifications = false

    private func requestNotificationPermissionIfNeeded() {
        guard !didRequestNotifications else { return }
        didRequestNotifications = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postCompletionNotification(totalSeconds: Int) {
        let loc = Localization.shared
        let content = UNMutableNotificationContent()
        content.title = loc.t("Timer finished", "Sayaç bitti")
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let duration = String(format: "%02d:%02d", minutes, seconds)
        content.body = loc.t("Your \(duration) timer is done.", "\(duration) sayacın tamamlandı.")
        content.sound = nil // Glass already plays in-app.

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
