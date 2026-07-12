import AppKit
import EventKit
import Combine

struct DayEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: NSColor
    let isAllDay: Bool
}

/// Today's calendar events via EventKit. Asks for full calendar access once;
/// if the user declines, the tile shows a retry hint.
final class EventsService: ObservableObject {
    static let shared = EventsService()

    enum Access { case unknown, granted, denied }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var events: [DayEvent] = []

    private let store = EKEventStore()
    private var timer: Timer?

    private init() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            access = .granted
            reload()
        case .notDetermined:
            access = .unknown
        default:
            access = .denied
        }

        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            self?.reload()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .EKEventStoreChanged, object: store
        )
    }

    @objc private func storeChanged() {
        reload()
    }

    /// First-launch behavior: trigger the system permission dialog right away
    /// instead of waiting for the user to find the button in the tile.
    func requestAccessIfNeeded() {
        if access == .unknown { requestAccess() }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                if granted { self?.reload() }
            }
        }
    }

    func reload() {
        guard access == .granted else { return }
        let calendar = Calendar.current
        let now = Date()
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return }
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let found = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            // Hide events that already fully ended.
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(10)
            .map { event in
                DayEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "—",
                    start: event.startDate,
                    end: event.endDate,
                    color: event.calendar?.color ?? .systemBlue,
                    isAllDay: event.isAllDay
                )
            }
        events = Array(found)
    }
}
