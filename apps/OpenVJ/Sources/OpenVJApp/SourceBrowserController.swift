import AppKit
import OpenUI
import OpenVJ
import UniformTypeIdentifiers

/// AppKit source picker for `SourceBrowser` scenes (local video folder + inter-app input discovery).
final class SourceBrowserController: NSObject, NSWindowDelegate {
    private let catalog: MacSourceCatalog
    private var sessions: [String: DeckSession] = [:]
    private var inputServersObserver: NSObjectProtocol?

    init(catalog: MacSourceCatalog) {
        self.catalog = catalog
        super.init()
    }

    private enum SourceBrowserRow: Equatable {
        case none
        case catalogEntry(SourceDescriptor)
        case manualInterAppInput(name: String)
    }

    private final class DeckSession {
        let deckID: String?
        var panel: NSPanel?
        var tableView: NSTableView?
        var rows: [SourceBrowserRow] = []
        var didAutoPresent = false

        init(deckID: String?) {
            self.deckID = deckID
        }
    }

    func install() {
        SourceBrowserUI.registerPresentHandler { [weak self] configuration in
            DispatchQueue.main.async {
                self?.handlePresent(configuration)
            }
        }
        inputServersObserver = NotificationCenter.default.addObserver(
            forName: InterAppTextureRegistry.Input.serversDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadAllRows(keepingSelection: true)
        }
    }

    deinit {
        if let inputServersObserver {
            NotificationCenter.default.removeObserver(inputServersObserver)
        }
        SourceBrowserUI.registerPresentHandler(nil)
    }

    func showPanel(deck: String? = nil) {
        let session = ensureSession(deckID: deck)
        session.panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reloadRows(session: session, keepingSelection: true)
    }

    private func handlePresent(_ configuration: SourceBrowserConfiguration) {
        let session = ensureSession(deckID: configuration.deckID)
        let state = selectionState(for: configuration.deckID)
        if let folder = configuration.mediaFolderURL {
            state.mediaFolderURL = folder
            if configuration.deckID == nil {
                catalog.mediaFolderURL = folder
            }
        } else if state.mediaFolderURL == nil {
            let fallback = catalog.mediaFolderURL ?? MacSourceCatalog.defaultMediaFolder()
            state.mediaFolderURL = fallback
        }
        if configuration.deckID == nil, catalog.mediaFolderURL == nil {
            catalog.mediaFolderURL = state.mediaFolderURL ?? MacSourceCatalog.defaultMediaFolder()
        }
        if !session.didAutoPresent {
            session.didAutoPresent = true
            session.panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        reloadRows(session: session, keepingSelection: true)
    }

    private func sessionKey(for deckID: String?) -> String {
        deckID ?? "main"
    }

    private func selectionState(for deckID: String?) -> SourceSelectionState {
        if let deckID {
            return SourceDeckRegistry.selectionState(for: deckID)
        }
        return catalog.selectionState
    }

    private func panelTitle(for deckID: String?) -> String {
        if let deckID {
            return "Sources (Deck \(deckID))"
        }
        return "Sources"
    }

    private func ensureSession(deckID: String?) -> DeckSession {
        let key = sessionKey(for: deckID)
        if let existing = sessions[key] {
            return existing
        }
        let session = DeckSession(deckID: deckID)
        sessions[key] = session
        buildPanel(for: session)
        return session
    }

    private func buildPanel(for session: DeckSession) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = panelTitle(for: session.deckID)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let scroll = NSScrollView(frame: panel.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let table = NSTableView(frame: scroll.bounds)
        table.headerView = nil
        table.usesAlternatingRowBackgroundColors = true
        table.delegate = self
        table.dataSource = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        column.title = "Source"
        column.width = 380
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        scroll.documentView = table
        session.tableView = table

        let stack = NSStackView(views: [scroll])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(stack)
        if let content = panel.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }

        let buttonBar = NSStackView()
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 8
        buttonBar.addArrangedSubview(makeButton(title: "Choose Folder…", action: #selector(chooseFolder(_:))))
        buttonBar.addArrangedSubview(makeButton(title: "Choose File…", action: #selector(chooseFile(_:))))
        buttonBar.addArrangedSubview(makeButton(title: "Add Inter-App Input…", action: #selector(addManualInterAppInput(_:))))
        buttonBar.addArrangedSubview(makeButton(title: "Refresh", action: #selector(refresh(_:))))
        stack.addArrangedSubview(buttonBar)

        session.panel = panel
        reloadRows(session: session, keepingSelection: false)
    }

    private func session(for tableView: NSTableView) -> DeckSession? {
        sessions.values.first(where: { $0.tableView === tableView })
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func refresh(_ sender: Any?) {
        reloadAllRows(keepingSelection: true)
    }

    @objc private func chooseFolder(_ sender: Any?) {
        let deckID = senderDeckID(sender)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectionState(for: deckID).mediaFolderURL ?? catalog.mediaFolderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectionState(for: deckID).mediaFolderURL = url
        if deckID == nil {
            catalog.mediaFolderURL = url
        }
        reloadAllRows(keepingSelection: false)
    }

    @objc private func chooseFile(_ sender: Any?) {
        let deckID = senderDeckID(sender)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectionState(for: deckID).mediaFolderURL ?? catalog.mediaFolderURL
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .video]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectionState(for: deckID).selection = .source(
            SourceDescriptor(displayName: url.lastPathComponent, kind: .localFile(url))
        )
        if let session = sessions[sessionKey(for: deckID)] {
            reloadRows(session: session, keepingSelection: true)
        }
    }

    @objc private func addManualInterAppInput(_ sender: Any?) {
        let deckID = senderDeckID(sender)
        let alert = NSAlert()
        alert.messageText = "Inter-app server name"
        alert.informativeText = "Enter the published server name from the sending app."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "Server name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        selectionState(for: deckID).selection = .source(
            SourceDescriptor(displayName: name, kind: .interAppInput(serverName: name))
        )
        if let session = sessions[sessionKey(for: deckID)] {
            reloadRows(session: session, keepingSelection: true)
        }
    }

    private func senderDeckID(_ sender: Any?) -> String? {
        guard let button = sender as? NSView else { return nil }
        var view: NSView? = button
        while let current = view {
            if let panel = current.window as? NSPanel,
               let session = sessions.values.first(where: { $0.panel === panel })
            {
                return session.deckID
            }
            view = current.superview
        }
        return nil
    }

    private func reloadAllRows(keepingSelection: Bool) {
        catalog.refresh()
        for session in sessions.values {
            reloadRows(session: session, keepingSelection: keepingSelection)
        }
    }

    private func reloadRows(session: DeckSession, keepingSelection: Bool) {
        catalog.refresh()
        let state = selectionState(for: session.deckID)
        var next: [SourceBrowserRow] = [.none]
        for entry in catalog.sources {
            next.append(.catalogEntry(entry.descriptor))
        }
        if case .source(let descriptor) = state.selection,
           case .interAppInput(let name) = descriptor.kind,
           !catalog.sources.contains(where: { $0.id == descriptor.id })
        {
            next.append(.manualInterAppInput(name: name))
        }

        session.rows = next
        session.tableView?.reloadData()
        syncTableSelection(session: session)

        if !keepingSelection {
            state.selection = .none
            syncTableSelection(session: session)
        }
    }

    private func syncTableSelection(session: DeckSession) {
        guard let tableView = session.tableView else { return }
        let selection = selectionState(for: session.deckID).selection
        let index = session.rows.firstIndex { row in
            switch (row, selection) {
            case (.none, .none):
                return true
            case (.catalogEntry(let descriptor), .source(let selected)):
                return descriptor.id == selected.id
            case (.manualInterAppInput(let name), .source(let selected)):
                if case .interAppInput(let serverName) = selected.kind {
                    return serverName == name
                }
                return false
            default:
                return false
            }
        } ?? 0
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    private func applySelection(for row: SourceBrowserRow, deckID: String?) {
        switch row {
        case .none:
            selectionState(for: deckID).selection = .none
        case .catalogEntry(let descriptor):
            selectionState(for: deckID).selection = .source(descriptor)
        case .manualInterAppInput(let name):
            selectionState(for: deckID).selection = .source(
                SourceDescriptor(displayName: name, kind: .interAppInput(serverName: name))
            )
        }
    }
}

extension SourceBrowserController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        session(for: tableView)?.rows.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let session = session(for: tableView) else { return nil }
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
            ?? NSTableCellView()
        cell.identifier = id
        if cell.textField == nil {
            let field = NSTextField(labelWithString: "")
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = displayName(for: session.rows[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView,
              let session = session(for: table) else { return }
        let index = table.selectedRow
        guard index >= 0, index < session.rows.count else { return }
        applySelection(for: session.rows[index], deckID: session.deckID)
    }

    private func displayName(for row: SourceBrowserRow) -> String {
        switch row {
        case .none:
            return "— None (generative only) —"
        case .catalogEntry(let descriptor):
            switch descriptor.kind {
            case .localFile:
                return "📁 \(descriptor.displayName)"
            case .interAppInput:
                return "◎ Inter-app: \(descriptor.displayName)"
            case .url, .captureDevice:
                return descriptor.displayName
            }
        case .manualInterAppInput(let name):
            return "◎ Inter-app (manual): \(name)"
        }
    }
}
