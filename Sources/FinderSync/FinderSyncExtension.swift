import AppKit
import FinderSync
import OSLog

private let extensionLogger = Logger(subsystem: "io.github.privRyan.FinderCreateFile.FinderSync", category: "OpenRequest")

final class FinderSyncExtension: FIFinderSync {
    private var settingsWindowController: FileTypeSettingsWindowController?

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
        submenu.addItem(item(title: "PowerPoint 演示文稿 (.pptx)", symbol: "rectangle.on.rectangle", action: #selector(createPowerPoint)))
        let enabledTypes = FileTypeSelection.enabledTypes(
            from: UserDefaults.standard.object(forKey: FileTypeSelection.defaultsKey)
        )
        for type in enabledTypes {
            let additional = item(
                title: "\(type.displayName) (.\(type.fileExtension))",
                symbol: type.symbol,
                action: #selector(createAdditional(_:))
            )
            guard let menuTag = FileTypeCatalog.menuTag(for: type.id) else { continue }
            additional.tag = menuTag
            submenu.addItem(additional)
        }
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
    @objc private func createPowerPoint() { create(type: "pptx") }

    @objc private func createAdditional(_ sender: NSMenuItem) {
        guard let type = FileTypeCatalog.type(menuTag: sender.tag) else { return }
        open(operation: "additional", typeID: type.id)
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
        guard let containingApp = ContainingAppLocator.locate(from: Bundle.main.bundleURL) else {
            extensionLogger.error("Containing app structure validation failed")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: containingApp,
            configuration: configuration
        ) { _, error in
            if let error {
                extensionLogger.error("Unable to open containing app, errorCode=\((error as NSError).code)")
            }
        }
    }

    private func presentFileTypeSettings() {
        let enabledIDs = Set(
            FileTypeSelection.enabledTypes(
                from: UserDefaults.standard.object(forKey: FileTypeSelection.defaultsKey)
            ).map(\.id)
        )
        guard settingsWindowController == nil else {
            if settingsWindowController?.present() != true {
                extensionLogger.error("Unable to switch to regular activation policy for settings")
            }
            return
        }
        let controller = FileTypeSettingsWindowController(
            types: FileTypeCatalog.additional,
            enabledIDs: enabledIDs,
            saveHandler: { selectedIDs in
                UserDefaults.standard.set(
                    FileTypeSelection.storedValue(enabledIDs: selectedIDs),
                    forKey: FileTypeSelection.defaultsKey
                )
            },
            closeHandler: { [weak self] in self?.settingsWindowController = nil }
        )
        settingsWindowController = controller
        if !controller.present() {
            extensionLogger.error("Unable to switch to regular activation policy for settings")
            settingsWindowController = nil
        }
    }
}
