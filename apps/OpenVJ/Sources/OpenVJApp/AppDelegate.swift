import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let visualView = VisualView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))

        let window = NSWindow(
            contentRect: visualView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenVJ"
        window.contentView = visualView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [.fullScreenPrimary]
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
