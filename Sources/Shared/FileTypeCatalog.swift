import Foundation

enum L10n {
    static var isChinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }
    static func text(_ chinese: String, _ english: String) -> String {
        isChinese ? chinese : english
    }
}

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
        BuiltInFileType(id: "json", displayName: L10n.text("JSON 文件", "JSON file"), fileExtension: "json", symbol: "curlybraces", defaultName: "data", strategy: .utf8("{}\n")),
        BuiltInFileType(id: "yaml", displayName: L10n.text("YAML 文件", "YAML file"), fileExtension: "yaml", symbol: "list.bullet.rectangle", defaultName: "config", strategy: .empty),
        BuiltInFileType(id: "html", displayName: L10n.text("HTML 文件", "HTML file"), fileExtension: "html", symbol: "chevron.left.forwardslash.chevron.right", defaultName: "index", strategy: .utf8("<!doctype html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title></title>\n</head>\n<body>\n</body>\n</html>\n")),
        BuiltInFileType(id: "css", displayName: L10n.text("CSS 文件", "CSS file"), fileExtension: "css", symbol: "paintbrush", defaultName: "styles", strategy: .empty),
        BuiltInFileType(id: "javascript", displayName: L10n.text("JavaScript 文件", "JavaScript file"), fileExtension: "js", symbol: "j.square", defaultName: "script", strategy: .empty),
        BuiltInFileType(id: "typescript", displayName: L10n.text("TypeScript 文件", "TypeScript file"), fileExtension: "ts", symbol: "t.square", defaultName: "index", strategy: .empty),
        BuiltInFileType(id: "python", displayName: L10n.text("Python 文件", "Python file"), fileExtension: "py", symbol: "chevron.left.forwardslash.chevron.right", defaultName: "main", strategy: .empty),
        BuiltInFileType(id: "shell", displayName: L10n.text("Shell 脚本", "Shell script"), fileExtension: "sh", symbol: "terminal", defaultName: "script", strategy: .utf8("#!/bin/sh\n")),
        BuiltInFileType(id: "xml", displayName: L10n.text("XML 文件", "XML file"), fileExtension: "xml", symbol: "chevron.left.forwardslash.chevron.right", defaultName: "document", strategy: .utf8("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root/>\n")),
        BuiltInFileType(id: "csv", displayName: L10n.text("CSV 文件", "CSV file"), fileExtension: "csv", symbol: "tablecells", defaultName: "data", strategy: .empty)
    ]

    static func type(id: String) -> BuiltInFileType? {
        additional.first { $0.id == id }
    }

    static func menuTag(for id: String) -> Int? {
        additional.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    static func type(menuTag: Int) -> BuiltInFileType? {
        let index = menuTag - 1
        guard additional.indices.contains(index) else { return nil }
        return additional[index]
    }
}

enum FileTypeSelection {
    static let defaultsKey = "enabledFileTypeIDs.v1"
    static let currentVersion = 1

    static func enabledTypes(from storedValue: Any?) -> [BuiltInFileType] {
        guard let dictionary = storedValue as? [String: Any],
              let version = dictionary["version"] as? Int,
              version == currentVersion,
              let identifiers = dictionary["enabledTypeIDs"] as? [String] else {
            return []
        }
        let selected = Set(identifiers)
        return FileTypeCatalog.additional.filter { selected.contains($0.id) }
    }

    static func storedValue(enabledIDs: Set<String>) -> [String: Any] {
        let orderedIDs = FileTypeCatalog.additional.map(\.id).filter(enabledIDs.contains)
        return ["version": currentVersion, "enabledTypeIDs": orderedIDs]
    }
}
