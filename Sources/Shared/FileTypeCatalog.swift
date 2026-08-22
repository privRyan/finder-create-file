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
