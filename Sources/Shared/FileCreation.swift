import Foundation
import Darwin

@_silgen_name("finder_create_file_exclusive")
private func finderCreateFileExclusive(_ path: UnsafePointer<CChar>) -> Int32

enum FileCreationError: LocalizedError {
    case invalidDirectory
    case directoryOutsideAllowedLocations
    case invalidName
    case tooManyConflicts

    var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            return "目标位置不存在或不是文件夹。"
        case .directoryOutsideAllowedLocations:
            return "只能在用户目录或 /Volumes 下创建文件。"
        case .invalidName:
            return "文件名不能为空，也不能包含 / 或 :。"
        case .tooManyConflicts:
            return "同名文件过多，无法生成可用名称。"
        }
    }
}

enum AppRequest: Equatable {
    case createFixed(type: String, path: String)
    case createAdditional(typeID: String, path: String)
}

enum AppRequestParser {
    static func parse(_ value: String) -> AppRequest? {
        guard let components = URLComponents(string: value), components.scheme == "findercreatefile" else {
            return nil
        }
        switch components.host {
        case "create":
            guard let type = components.queryItems?.first(where: { $0.name == "type" })?.value,
                  FileCreator.supportedTypes.contains(type),
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value else {
                return nil
            }
            return .createFixed(type: type, path: path)
        case "additional":
            guard let typeID = components.queryItems?.first(where: { $0.name == "typeID" })?.value,
                  FileTypeCatalog.type(id: typeID) != nil,
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value else { return nil }
            return .createAdditional(typeID: typeID, path: path)
        default:
            return nil
        }
    }
}

enum FileCreator {
    static let supportedTypes = ["txt", "md", "docx", "xlsx", "pptx"]

    static func normalizedTargetDirectory(_ path: String) throws -> URL {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileCreationError.invalidDirectory
        }

        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard isEqualOrDescendant(directory, of: home) || isEqualOrDescendant(directory, of: volumes) else {
            throw FileCreationError.directoryOutsideAllowedLocations
        }
        return directory
    }

    static func create(rawName: String, type: String, directory: URL, template: URL?, generatedContents: Data? = nil) throws -> URL {
        let normalizedType = try normalizedExtension(type)
        let (rootName, requestedName) = try normalizedName(rawName, type: type)
        let contents = try template.map { try Data(contentsOf: $0) } ?? generatedContents ?? Data()

        for index in 1...10_000 {
            let filename = index == 1 ? requestedName : "\(rootName) \(index).\(normalizedType)"
            let destination = directory.appendingPathComponent(filename, isDirectory: false)
            do {
                try writeExclusively(contents, to: destination)
                return destination
            } catch let error as POSIXError where error.code == .EEXIST {
                continue
            }
        }
        throw FileCreationError.tooManyConflicts
    }

    static func normalizedName(_ rawName: String, type: String) throws -> (root: String, filename: String) {
        let type = try normalizedExtension(type)
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains(":") else {
            throw FileCreationError.invalidName
        }
        let suffix = ".\(type)"
        let hasSuffix = name.lowercased().hasSuffix(suffix)
        let root = hasSuffix ? String(name.dropLast(suffix.count)) : name
        guard !root.isEmpty else { throw FileCreationError.invalidName }
        return (root, hasSuffix ? name : name + suffix)
    }

    static func normalizedExtension(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+-_"))
        guard !value.isEmpty, value.count <= 16,
              value.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              value.unicodeScalars.first.map(CharacterSet.alphanumerics.contains) == true else {
            throw FileCreationError.invalidName
        }
        return value
    }

    private static func isEqualOrDescendant(_ candidate: URL, of root: URL) -> Bool {
        candidate.path == root.path || candidate.path.hasPrefix(root.path + "/")
    }

    private static func writeExclusively(_ data: Data, to destination: URL) throws {
        let descriptor = destination.withUnsafeFileSystemRepresentation { path in
            finderCreateFileExclusive(path!)
        }
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

        defer { close(descriptor) }
        try data.withUnsafeBytes { rawBuffer in
            guard var cursor = rawBuffer.baseAddress else { return }
            var remaining = rawBuffer.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, cursor, remaining)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                remaining -= count
                cursor = cursor.advanced(by: count)
            }
        }
    }
}
