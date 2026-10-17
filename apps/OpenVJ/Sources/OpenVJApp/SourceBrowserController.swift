import AppKit
import OpenUI
import OpenVJ
import UniformTypeIdentifiers

/// AppKit source picker for `SourceBrowser` scenes (local video folder + inter-app input discovery).
final class SourceBrowserController: NSObject, NSWindowDelegate {
    private let catalog: MacSourceCatalog
    private var panel: NSPanel?
    private var tableView: NSTableView?
    private var rows: [SourceBrowserRow] = []
    private var inputServersObserver: NSObjectProtocol?
    private var didAutoPresent = false

    init(catalog: MacSourceCatalog) {
        self.catalog = catalog
        super.init()
    }

    private enum SourceBrowserRow: Equatable {
        case none
        case catalogEntry(SourceDescriptor)
        case manualInterAppInput(name: String)
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
            self?.reloadRows(keepingSelection: true)
        }
    }

    deinit {
        if let inputServersObserver {
            NotificationCenter.default.removeObserver(inputServersObserver)
        }
        SourceBrowserUI.registerPresentHandler(nil)
    }

    func showPanel() {
        ensurePanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reloadRows(keepingSelection: true)
    }

    private func handlePresent(_ configuration: SourceBrowserConfiguration) {
        if let folder = configuration.mediaFolderURL {
            catalog.mediaFolderURL = folder
        } else if catalog.mediaFolderURL == nil {
            catalog.mediaFolderURL = catalog.selectionState.mediaFolderURL ?? MacSourceCatalog.defaultMediaFolder()
        }
        if !didAutoPresent {
            didAutoPresent = true
            showPanel()
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Sources"
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
        tableView = table

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

        self.panel = panel
        reloadRows(keepingSelection: false)
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func refresh(_ sender: Any?) {
        reloadRows(keepingSelection: true)
    }

    @objc private func chooseFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = catalog.mediaFolderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        catalog.mediaFolderURL = url
        reloadRows(keepingSelection: false)
    }

    @objc private func chooseFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = catalog.mediaFolderURL
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .video]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        catalog.selectionState.selection = .source(
            SourceDescriptor(displayName: url.lastPathComponent, kind: .localFile(url))
        )
        reloadRows(keepingSelection: true)
    }

    @objc private func addManualInterAppInput(_ sender: Any?) {
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
        catalog.selectionState.selection = .source(
            SourceDescriptor(displayName: name, kind: .interAppInput(serverName: name))
        )
        reloadRows(keepingSelection: true)
    }

    private func reloadRows(keepingSelection: Bool) {
        catalog.refresh()
        var next: [SourceBrowserRow] = [.none]
        for entry in catalog.sources {
            next.append(.catalogEntry(entry.descriptor))
        }
        if case .source(let descriptor) = catalog.selectionState.selection,
           case .interAppInput(let name) = descriptor.kind,
           !catalog.sources.contains(where: { $0.id == descriptor.id })
        {
            next.append(.manualInterAppInput(name: name))
        }

        rows = next
        tableView?.reloadData()
        syncTableSelectionToCatalog()

        if !keepingSelection {
            catalog.selectionState.selection = .none
            syncTableSelectionToCatalog()
        }
    }

    private func syncTableSelectionToCatalog() {
        guard let tableView else { return }
        let selection = catalog.selectionState.selection
        let index = rows.firstIndex { row in
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

    private func applySelection(for row: SourceBrowserRow) {
        switch row {
        case .none:
            catalog.selectionState.selection = .none
        case .catalogEntry(let descriptor):
            catalog.selectionState.selection = .source(descriptor)
        case .manualInterAppInput(let name):
            catalog.selectionState.selection = .source(
                SourceDescriptor(displayName: name, kind: .interAppInput(serverName: name))
            )
        }
    }
}

extension SourceBrowserController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
        cell.textField?.stringValue = displayName(for: rows[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let index = table.selectedRow
        guard index >= 0, index < rows.count else { return }
        applySelection(for: rows[index])
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
