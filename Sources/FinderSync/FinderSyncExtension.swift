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
        submenu.addItem(item(title: "更多文件类型…", symbol: "doc.badge.plus", action: #selector(createCustom)))
        submenu.addItem(item(title: "管理文件类型…", symbol: "gearshape", action: #selector(manageCustomTypes)))

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
    @objc private func createCustom() { open(operation: "custom", type: nil, includePath: true) }
    @objc private func manageCustomTypes() { open(operation: "manage", type: nil, includePath: false) }

    private func create(type: String) {
        open(operation: "create", type: type, includePath: true)
    }

    private func open(operation: String, type: String?, includePath: Bool) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        let directory = target.hasDirectoryPath ? target : target.deletingLastPathComponent()
        var components = URLComponents()
        components.scheme = "findercreatefile"
        components.host = operation
        var queryItems: [URLQueryItem] = []
        if let type { queryItems.append(URLQueryItem(name: "type", value: type)) }
        if includePath { queryItems.append(URLQueryItem(name: "path", value: directory.path)) }
        components.queryItems = queryItems
        if let url = components.url { NSWorkspace.shared.open(url) }
    }
}
