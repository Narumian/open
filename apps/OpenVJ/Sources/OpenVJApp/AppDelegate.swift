import AppKit
import MetalKit
import OpenVJ

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var renderer: MetalVisualRenderer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mtkView = MTKView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        guard let renderer = MetalVisualRenderer(mtkView: mtkView) else {
            fatalError("Metal is unavailable on this Mac.")
        }
        self.renderer = renderer

        let window = NSWindow(
            contentRect: mtkView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenVJ"
        window.contentView = mtkView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [.fullScreenPrimary]
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
