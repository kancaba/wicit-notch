import Foundation
import Combine
import IOKit.ps

struct BatteryStatus: Equatable {
    var percent: Int
    var isCharging: Bool

    /// Closest SF Symbol for the current level.
    var symbol: String {
        if isCharging { return "battery.100percent.bolt" }
        let bucket = [0, 25, 50, 75, 100].min(by: {
            abs($0 - percent) < abs($1 - percent)
        }) ?? 100
        return "battery.\(bucket)percent"
    }
}

/// Reads the internal battery via IOKit power sources (public API, no perms).
final class BatteryService: ObservableObject {
    static let shared = BatteryService()

    @Published private(set) var status: BatteryStatus?

    private var timer: Timer?

    private init() {
        read()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.read()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func read() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            status = nil
            return
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType
            else { continue }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let charging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            status = BatteryStatus(
                percent: max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : 0,
                isCharging: charging
            )
            return
        }
        status = nil
    }
}
