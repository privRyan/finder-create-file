import AppKit
import Carbon

private struct FileConfiguration {
    let title: String
    let defaultName: String
    let resourceName: String?
    let symbol: String
    let color: NSColor
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard
            let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let request = AppRequestParser.parse(value)
        else { return }

        NSApp.activate(ignoringOtherApps: true)
        if request == .manageTypes {
            FileTypeSettingsController().run()
            return
        }

        do {
            switch request {
            case .createFixed(let type, let path):
                let targetDirectory = try FileCreator.normalizedTargetDirectory(path)
                createFile(type: type, directory: targetDirectory)
            case .createAdditional(let path):
                let targetDirectory = try FileCreator.normalizedTargetDirectory(path)
                chooseAdditionalType(directory: targetDirectory)
            case .manageTypes:
                break
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func configuration(for type: String) -> FileConfiguration? {
        switch type {
        case "txt":
            return FileConfiguration(title: "新建 TXT 文件", defaultName: "新建文本文档", resourceName: nil, symbol: "doc.plaintext", color: .systemBlue)
        case "md":
            return FileConfiguration(title: "新建 Markdown 文件", defaultName: "README", resourceName: nil, symbol: "doc.text", color: .systemPurple)
        case "docx":
            return FileConfiguration(title: "新建 Word 文档", defaultName: "新建 Word 文档", resourceName: "blank.docx", symbol: "doc.richtext", color: .systemIndigo)
        case "xlsx":
            return FileConfiguration(title: "新建 Excel 工作簿", defaultName: "新建 Excel 工作簿", resourceName: "blank.xlsx", symbol: "tablecells", color: .systemGreen)
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
        prompt.informativeText = "创建位置：\(directory.path)\n\n请输入文件名："
        prompt.accessoryView = input
        prompt.addButton(withTitle: "创建")
        prompt.addButton(withTitle: "取消")
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

    private func chooseAdditionalType(directory: URL) {
        let values = FileTypeSettingsStore.shared.enabledTypes()
        guard !values.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "还没有启用额外文件类型"
            alert.informativeText = "请先从内置的受支持类型中勾选需要的项目。"
            alert.addButton(withTitle: "管理文件类型")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn { FileTypeSettingsController().run() }
            return
        }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 340, height: 26))
        popup.addItems(withTitles: values.map { "\($0.displayName) (.\($0.fileExtension))" })
        let selector = NSAlert()
        selector.messageText = "新建更多类型的文件"
        selector.informativeText = "创建位置：\(directory.path)"
        selector.accessoryView = popup
        selector.addButton(withTitle: "下一步")
        selector.addButton(withTitle: "取消")
        guard selector.runModal() == .alertFirstButtonReturn, popup.indexOfSelectedItem >= 0 else { return }
        createAdditionalFile(values[popup.indexOfSelectedItem], directory: directory)
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
        prompt.messageText = "新建\(value.displayName)"
        prompt.informativeText = "创建位置：\(directory.path)\n\n请输入文件名："
        prompt.accessoryView = input
        prompt.addButton(withTitle: "创建")
        prompt.addButton(withTitle: "取消")
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
        alert.messageText = "无法创建文件"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

@main
struct FinderCreateFileApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
