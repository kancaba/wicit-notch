import Foundation
import Combine

/// Keep-awake toggle backed by the system `caffeinate` tool: while active the
/// display and system won't sleep.
final class CaffeineService: ObservableObject {
    static let shared = CaffeineService()

    @Published private(set) var isActive = false

    private var process: Process?

    private init() {}

    func toggle() {
        isActive ? stop() : start()
    }

    private func start() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-di"]
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.isActive = false }
        }
        do {
            try process.run()
            self.process = process
            isActive = true
        } catch {
            isActive = false
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isActive = false
    }
}
