import AppKit

// Wicit runs as a menu-bar agent (LSUIElement). We drive NSApplication
// manually so the notch panel is available immediately at launch.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
