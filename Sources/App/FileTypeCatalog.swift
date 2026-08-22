import AppKit
import Foundation

enum BuiltInCreationStrategy {
    case empty
    case utf8(String)

    var data: Data {
        switch self {
        case .empty: return Data()
        case .utf8(let text): return Data(text.utf8)
        }
    }
}

struct BuiltInFileType {
    let id: String
    let displayName: String
    let fileExtension: String
    let symbol: String
    let defaultName: String
    let strategy: BuiltInCreationStrategy
}

enum FileTypeCatalog {
    static let additional: [BuiltInFileType] = [
        BuiltInFileType(id: "json", displayName: "JSON 文件", fileExtension: "json", symbol: "curlybraces", defaultName: "data", strategy: .utf8("{}\n")),
        BuiltInFileType(id: "yaml", displayName: "YAML 文件", fileExtension: "yaml", symbol: "list.bullet.rectangle", defaultName: "config", strategy: .empty),
        BuiltInFileType(id: "html", displayName: "HTML 文件", fileExtension: "html", symbol: "chevron.left.forwardslash.chevron.right", defaultName: "index", strategy: .utf8("<!doctype html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title></title>\n</head>\n<body>\n</body>\n</html>\n")),
        BuiltInFileType(id: "css", displayName: "CSS 文件", fileExtension: "css", symbol: "paintbrush", defaultName: "styles", strategy: .empty),
        BuiltInFileType(id: "javascript", displayName: "JavaScript 文件", fileExtension: "js", symbol: "j.square", defaultName: "script", strategy: .empty),
        BuiltInFileType(id: "typescript", displayName: "TypeScript 文件", fileExtension: "ts", symbol: "t.square", defaultName: "index", strategy: .empty),
        BuiltInFileType(id: "python", displayName: "Python 文件", fileExtension: "py", symbol: "chevron.left.forwardslash.chevron.right", defaultName: "main", strategy: .empty),
        BuiltInFileType(id: "shell", displayName: "Shell 脚本", fileExtension: "sh", symbol: "terminal", defaultName: "script", strategy: .utf8("#!/bin/sh\n")),
        BuiltInFileType(id: "xml", displayName: "XML 文件", fileExtension: "xml", symbol: "chevron.left.forwardslash.chevron.right", defaultName: "document", strategy: .utf8("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root/>\n")),
        BuiltInFileType(id: "csv", displayName: "CSV 文件", fileExtension: "csv", symbol: "tablecells", defaultName: "data", strategy: .empty)
    ]

    static func type(id: String) -> BuiltInFileType? {
        additional.first { $0.id == id }
    }
}

private struct FileTypeSettings: Codable {
    let version: Int
    let enabledTypeIDs: [String]
}

final class FileTypeSettingsStore {
    static let shared = FileTypeSettingsStore()
    static let currentVersion = 1

    private let configurationURL: URL

    private init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configurationURL = applicationSupport
            .appendingPathComponent("FinderCreateFile", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    func enabledTypes() -> [BuiltInFileType] {
        Self.enabledTypes(from: try? Data(contentsOf: configurationURL))
    }

    static func enabledTypes(from data: Data?) -> [BuiltInFileType] {
        guard let data,
              let settings = try? JSONDecoder().decode(FileTypeSettings.self, from: data),
              settings.version == Self.currentVersion else {
            return []
        }
        let enabled = Set(settings.enabledTypeIDs)
        return FileTypeCatalog.additional.filter { enabled.contains($0.id) }
    }

    func save(enabledIDs: Set<String>) throws {
        let data = try Self.encodedSettings(enabledIDs: enabledIDs)
        let directory = configurationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: configurationURL, options: .atomic)
    }

    static func encodedSettings(enabledIDs: Set<String>) throws -> Data {
        let knownIDs = Set(FileTypeCatalog.additional.map(\.id))
        let orderedIDs = FileTypeCatalog.additional.map(\.id).filter { enabledIDs.contains($0) && knownIDs.contains($0) }
        let settings = FileTypeSettings(version: Self.currentVersion, enabledTypeIDs: orderedIDs)
        return try JSONEncoder().encode(settings)
    }
}

final class FileTypeSettingsController {
    func run() {
        let enabledIDs = Set(FileTypeSettingsStore.shared.enabledTypes().map(\.id))
        let checkboxes = FileTypeCatalog.additional.map { type -> (BuiltInFileType, NSButton) in
            let button = NSButton(checkboxWithTitle: "\(type.displayName) (.\(type.fileExtension))", target: nil, action: nil)
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
        alert.informativeText = "默认的 TXT、Markdown、Word 和 Excel 始终保留。勾选需要在“更多文件类型”中显示的额外类型。"
        alert.accessoryView = columns
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let selected = Set(checkboxes.filter { $0.1.state == .on }.map { $0.0.id })
            try FileTypeSettingsStore.shared.save(enabledIDs: selected)
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "无法保存文件类型设置"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }
}
