import AppKit
import FinderSync

final class FinderSyncExtension: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer else { return nil }

        let menu = NSMenu(title: "")
        let root = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)

        let submenu = NSMenu(title: "新建文件")
        submenu.addItem(item(title: "文本文档 (.txt)", symbol: "doc.plaintext", action: #selector(createTXT)))
        submenu.addItem(item(title: "Markdown 文件 (.md)", symbol: "doc.text", action: #selector(createMarkdown)))
        submenu.addItem(item(title: "Word 文档 (.docx)", symbol: "doc.richtext", action: #selector(createWord)))
        submenu.addItem(item(title: "Excel 工作簿 (.xlsx)", symbol: "tablecells", action: #selector(createExcel)))
        submenu.addItem(.separator())

        let enabledTypes = FileTypeSelection.enabledTypes(
            from: UserDefaults.standard.object(forKey: FileTypeSelection.defaultsKey)
        )
        for type in enabledTypes {
            let additional = item(
                title: "\(type.displayName) (.\(type.fileExtension))",
                symbol: type.symbol,
                action: #selector(createAdditional(_:))
            )
            additional.representedObject = type.id
            submenu.addItem(additional)
        }
        if !enabledTypes.isEmpty { submenu.addItem(.separator()) }
        submenu.addItem(item(title: "管理文件类型…", symbol: "gearshape", action: #selector(manageFileTypes)))

        root.submenu = submenu
        menu.addItem(root)
        return menu
    }

    private func item(title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    @objc private func createTXT() { create(type: "txt") }
    @objc private func createMarkdown() { create(type: "md") }
    @objc private func createWord() { create(type: "docx") }
    @objc private func createExcel() { create(type: "xlsx") }

    @objc private func createAdditional(_ sender: NSMenuItem) {
        guard let typeID = sender.representedObject as? String,
              FileTypeCatalog.type(id: typeID) != nil else { return }
        open(operation: "additional", typeID: typeID)
    }

    @objc private func manageFileTypes() {
        DispatchQueue.main.async { [weak self] in self?.presentFileTypeSettings() }
    }

    private func create(type: String) {
        open(operation: "create", type: type)
    }

    private func open(operation: String, type: String? = nil, typeID: String? = nil) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        let directory = target.hasDirectoryPath ? target : target.deletingLastPathComponent()
        var components = URLComponents()
        components.scheme = "findercreatefile"
        components.host = operation
        var queryItems: [URLQueryItem] = []
        if let type { queryItems.append(URLQueryItem(name: "type", value: type)) }
        if let typeID { queryItems.append(URLQueryItem(name: "typeID", value: typeID)) }
        queryItems.append(URLQueryItem(name: "path", value: directory.path))
        components.queryItems = queryItems
        guard let url = components.url else { return }
        let containingApp = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .resolvingSymlinksInPath()
        guard containingApp.pathExtension == "app",
              let extensionID = Bundle.main.bundleIdentifier,
              extensionID.hasSuffix(".FinderSync"),
              let appBundle = Bundle(url: containingApp),
              appBundle.bundleIdentifier == String(extensionID.dropLast(".FinderSync".count)),
              let executable = appBundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: containingApp,
            configuration: configuration
        )
    }

    private func presentFileTypeSettings() {
        let enabledIDs = Set(
            FileTypeSelection.enabledTypes(
                from: UserDefaults.standard.object(forKey: FileTypeSelection.defaultsKey)
            ).map(\.id)
        )
        let checkboxes = FileTypeCatalog.additional.map { type -> (BuiltInFileType, NSButton) in
            let button = NSButton(
                checkboxWithTitle: "\(type.displayName) (.\(type.fileExtension))",
                target: nil,
                action: nil
            )
            button.state = enabledIDs.contains(type.id) ? .on : .off
            return (type, button)
        }
        let left = NSStackView(views: checkboxes.prefix(5).map(\.1))
        let right = NSStackView(views: checkboxes.suffix(5).map(\.1))
        for column in [left, right] {
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 7
        }
        let columns = NSStackView(views: [left, right])
        columns.spacing = 28

        let alert = NSAlert()
        alert.messageText = "管理文件类型"
        alert.informativeText = "默认的 TXT、Markdown、Word 和 Excel 始终保留。勾选的额外类型会直接显示在访达右键菜单中。"
        alert.accessoryView = columns
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let selectedIDs = Set(checkboxes.filter { $0.1.state == .on }.map { $0.0.id })
        UserDefaults.standard.set(
            FileTypeSelection.storedValue(enabledIDs: selectedIDs),
            forKey: FileTypeSelection.defaultsKey
        )
    }
}
