import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private weak var visualView: VisualView?
    private var syphonMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let visualView = VisualView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        self.visualView = visualView

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
        configureMainMenu()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit OpenVJ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let viewMenuItem = NSMenuItem()
        viewMenuItem.title = "View"
        mainMenu.addItem(viewMenuItem)

        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let syphonItem = NSMenuItem(
            title: "Publish to Syphon",
            action: #selector(toggleSyphonPublishing(_:)),
            keyEquivalent: ""
        )
        syphonItem.target = self
        syphonItem.state = InterAppTextureSettings.syphonRequestedAtLaunch ? .on : .off
        viewMenu.addItem(syphonItem)
        syphonMenuItem = syphonItem

        let sourcesItem = NSMenuItem(
            title: "Source Browser…",
            action: #selector(showSourceBrowser(_:)),
            keyEquivalent: "b"
        )
        sourcesItem.keyEquivalentModifierMask = [.command, .shift]
        sourcesItem.target = self
        viewMenu.addItem(sourcesItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showSourceBrowser(_ sender: Any?) {
        visualView?.showSourceBrowser()
    }

    @objc private func toggleSyphonPublishing(_ sender: NSMenuItem) {
        let next = sender.state != .on
        sender.state = next ? .on : .off
        visualView?.setInterAppPublishing(next)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
