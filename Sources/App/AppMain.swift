import AppKit
import ServiceManagement

private struct FileConfiguration {
    let title: String
    let defaultName: String
    let resourceName: String?
    let symbol: String
    let color: NSColor
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var setupWindow: SetupWindowController?
    private var receivedRequest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, !self.receivedRequest else { return }
            self.showSetupIfNeeded()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedRequest = true
        for url in urls { handle(url.absoluteString) }
    }

    private func showSetupIfNeeded() {
        let loginEnabled = SMAppService.mainApp.status == .enabled
        let finderEnabled = FinderExtensionStatus.isEnabled
        guard !loginEnabled || !finderEnabled else { return }
        setupWindow = SetupWindowController(loginMissing: !loginEnabled, finderMissing: !finderEnabled)
        setupWindow?.showWindow(nil)
    }

    private func handle(_ value: String) {
        guard let request = AppRequestParser.parse(value) else { return }

        NSApp.activate(ignoringOtherApps: true)
        do {
            switch request {
            case .createFixed(let type, let path):
                let targetDirectory = try FileCreator.normalizedTargetDirectory(path)
                createFile(type: type, directory: targetDirectory)
            case .createAdditional(let typeID, let path):
                let targetDirectory = try FileCreator.normalizedTargetDirectory(path)
                guard let type = FileTypeCatalog.type(id: typeID) else { return }
                createAdditionalFile(type, directory: targetDirectory)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func configuration(for type: String) -> FileConfiguration? {
        switch type {
        case "txt":
            return FileConfiguration(title: L10n.text("新建 TXT 文件", "New TXT File"), defaultName: L10n.text("新建文本文档", "New Text Document"), resourceName: nil, symbol: "doc.plaintext", color: .systemBlue)
        case "md":
            return FileConfiguration(title: L10n.text("新建 Markdown 文件", "New Markdown File"), defaultName: "README", resourceName: nil, symbol: "doc.text", color: .systemPurple)
        case "docx":
            return FileConfiguration(title: L10n.text("新建 Word 文档", "New Word Document"), defaultName: L10n.text("新建 Word 文档", "New Word Document"), resourceName: "blank.docx", symbol: "doc.richtext", color: .systemIndigo)
        case "xlsx":
            return FileConfiguration(title: L10n.text("新建 Excel 工作簿", "New Excel Workbook"), defaultName: L10n.text("新建 Excel 工作簿", "New Excel Workbook"), resourceName: "blank.xlsx", symbol: "tablecells", color: .systemGreen)
        case "pptx":
            return FileConfiguration(title: L10n.text("新建 PowerPoint 演示文稿", "New PowerPoint Presentation"), defaultName: L10n.text("新建 PowerPoint 演示文稿", "New PowerPoint Presentation"), resourceName: "blank.pptx", symbol: "rectangle.on.rectangle", color: .systemOrange)
        default:
            return nil
        }
    }

    private func createFile(type: String, directory: URL) {
        guard let configuration = configuration(for: type) else { return }

        NSApp.activate(ignoringOtherApps: true)
        let input = NSTextField(string: configuration.defaultName)
        input.frame = NSRect(x: 0, y: 0, width: 320, height: 24)

        let prompt = NSAlert()
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 52, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [configuration.color]))
        prompt.icon = NSImage(systemSymbolName: configuration.symbol, accessibilityDescription: configuration.title)?
            .withSymbolConfiguration(symbolConfiguration)
        prompt.messageText = configuration.title
        prompt.informativeText = L10n.text("创建位置：\(directory.path)\n\n请输入文件名：", "Location: \(directory.path)\n\nEnter a filename:")
        prompt.accessoryView = input
        prompt.addButton(withTitle: L10n.text("创建", "Create"))
        prompt.addButton(withTitle: L10n.text("取消", "Cancel"))
        prompt.window.initialFirstResponder = input
        input.selectText(nil)

        guard prompt.runModal() == .alertFirstButtonReturn else { return }

        do {
            var template: URL?
            if let resourceName = configuration.resourceName {
                template = Bundle.main.resourceURL?.appendingPathComponent("Templates/\(resourceName)")
                guard template.map({ FileManager.default.fileExists(atPath: $0.path) }) == true else {
                    throw CocoaError(.fileNoSuchFile)
                }
            }
            let destination = try FileCreator.create(rawName: input.stringValue, type: type, directory: directory, template: template)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func createAdditionalFile(_ value: BuiltInFileType, directory: URL) {
        guard FileTypeCatalog.type(id: value.id)?.fileExtension == value.fileExtension else { return }
        let input = NSTextField(string: value.defaultName)
        input.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        let prompt = NSAlert()
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 52, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemOrange]))
        prompt.icon = NSImage(systemSymbolName: value.symbol, accessibilityDescription: value.displayName)?
            .withSymbolConfiguration(symbolConfiguration)
        prompt.messageText = L10n.text("新建\(value.displayName)", "New \(value.displayName)")
        prompt.informativeText = L10n.text("创建位置：\(directory.path)\n\n请输入文件名：", "Location: \(directory.path)\n\nEnter a filename:")
        prompt.accessoryView = input
        prompt.addButton(withTitle: L10n.text("创建", "Create"))
        prompt.addButton(withTitle: L10n.text("取消", "Cancel"))
        prompt.window.initialFirstResponder = input
        input.selectText(nil)
        guard prompt.runModal() == .alertFirstButtonReturn else { return }

        do {
            let destination = try FileCreator.create(
                rawName: input.stringValue, type: value.fileExtension,
                directory: directory, template: nil, generatedContents: value.strategy.data
            )
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.text("无法创建文件", "Could Not Create File")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

@main
struct FinderCreateFileApplication {
    private static let delegate = AppDelegate()

    static func main() {
        if CommandLine.arguments.dropFirst() == ["--unregister-login-item"] {
            if SMAppService.mainApp.status == .notRegistered { return }
            do { try SMAppService.mainApp.unregister() }
            catch {
                fputs("Could not remove login item: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            return
        }
        let application = NSApplication.shared
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
