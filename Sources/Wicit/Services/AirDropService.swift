import AppKit

/// Thin wrapper over `NSSharingService` to forward dropped items into AirDrop.
enum AirDropService {
    static func share(_ urls: [URL], from view: NSView? = nil) {
        guard !urls.isEmpty else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            NSSound.beep()
            return
        }
        guard service.canPerform(withItems: urls) else {
            NSSound.beep()
            return
        }
        service.perform(withItems: urls)
    }
}
