import AppKit
import Foundation

@main
struct CatalogTests {
    static func main() throws {
        let catalog = FileTypeCatalog.additional
        precondition(catalog.count == 10)
        precondition(Set(catalog.map(\.id)).count == catalog.count)
        precondition(Set(catalog.map(\.fileExtension)).count == catalog.count)
        precondition(catalog.map(\.fileExtension) == ["json", "yaml", "html", "css", "js", "ts", "py", "sh", "xml", "csv"])
        precondition(!catalog.map(\.fileExtension).contains("yml"))

        for type in catalog {
            precondition(!type.id.isEmpty)
            precondition(!type.displayName.isEmpty)
            precondition(!type.defaultName.isEmpty)
            let normalizedExtension = try FileCreator.normalizedExtension(type.fileExtension)
            precondition(normalizedExtension == type.fileExtension)
        }
        precondition(FileTypeCatalog.type(id: "missing") == nil)
        for (index, type) in catalog.enumerated() {
            let tag = index + 1
            precondition(FileTypeCatalog.menuTag(for: type.id) == tag)
            precondition(FileTypeCatalog.type(menuTag: tag)?.id == type.id)
        }
        precondition(FileTypeCatalog.menuTag(for: "missing") == nil)
        precondition(FileTypeCatalog.type(menuTag: 0) == nil)
        precondition(FileTypeCatalog.type(menuTag: catalog.count + 1) == nil)
        precondition(String(data: FileTypeCatalog.type(id: "json")!.strategy.data, encoding: .utf8) == "{}\n")
        precondition(String(data: FileTypeCatalog.type(id: "xml")!.strategy.data, encoding: .utf8)?.contains("<root/>") == true)
        precondition(String(data: FileTypeCatalog.type(id: "html")!.strategy.data, encoding: .utf8)?.contains("<!doctype html>") == true)

        let untrusted: [String: Any] = [
            "version": 1,
            "enabledTypeIDs": ["xml", "unknown", "json", "xml", "css"]
        ]
        precondition(FileTypeSelection.enabledTypes(from: untrusted).map(\.id) == ["json", "css", "xml"])
        precondition(FileTypeSelection.enabledTypes(from: ["version": 2, "enabledTypeIDs": ["json"]]).isEmpty)
        precondition(FileTypeSelection.enabledTypes(from: ["version": 1, "enabledTypeIDs": "json"]).isEmpty)
        precondition(FileTypeSelection.enabledTypes(from: "damaged").isEmpty)
        precondition(FileTypeSelection.enabledTypes(from: nil).isEmpty)

        let encoded = FileTypeSelection.storedValue(enabledIDs: Set(["csv", "json", "unknown", "csv"]))
        precondition(FileTypeSelection.enabledTypes(from: encoded).map(\.id) == ["json", "csv"])

        let validExtension = URL(fileURLWithPath:
            "/Applications/FinderCreateFile.app/Contents/PlugIns/FinderCreateFileFinderSync.appex"
        )
        precondition(ContainingAppLocator.locate(from: validExtension)?.path == "/Applications/FinderCreateFile.app")
        precondition(ContainingAppLocator.locate(from: URL(string: "https://example.test/extension")!) == nil)
        precondition(ContainingAppLocator.locate(from: URL(fileURLWithPath:
            "/Applications/Other.app/Contents/PlugIns/FinderCreateFileFinderSync.appex"
        )) == nil)
        precondition(ContainingAppLocator.locate(from: URL(fileURLWithPath:
            "/Applications/FinderCreateFile.app/Contents/Extensions/FinderCreateFileFinderSync.appex"
        )) == nil)
        precondition(ContainingAppLocator.locate(from: URL(fileURLWithPath:
            "/Applications/FinderCreateFile.app/Contents/PlugIns/Other.appex"
        )) == nil)

        let locatorRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-create-file-locator-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: locatorRoot) }
        let realApp = locatorRoot.appendingPathComponent("real/FinderCreateFile.app", isDirectory: true)
        let realExtension = realApp.appendingPathComponent(
            "Contents/PlugIns/FinderCreateFileFinderSync.appex", isDirectory: true
        )
        try FileManager.default.createDirectory(at: realExtension, withIntermediateDirectories: true)
        let linkedApp = locatorRoot.appendingPathComponent("FinderCreateFile.app", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedApp, withDestinationURL: realApp)
        let linkedExtension = linkedApp.appendingPathComponent(
            "Contents/PlugIns/FinderCreateFileFinderSync.appex", isDirectory: true
        )
        precondition(ContainingAppLocator.locate(from: linkedExtension) == nil)

        let fixed = AppRequestParser.parse("findercreatefile://create?type=txt&path=%2FUsers%2Ftester")
        precondition(fixed == .createFixed(type: "txt", path: "/Users/tester"))
        let fixedPowerPoint = AppRequestParser.parse("findercreatefile://create?type=pptx&path=%2FUsers%2Ftester")
        precondition(fixedPowerPoint == .createFixed(type: "pptx", path: "/Users/tester"))
        let additional = AppRequestParser.parse("findercreatefile://additional?typeID=json&path=%2FUsers%2Ftester")
        precondition(additional == .createAdditional(typeID: "json", path: "/Users/tester"))
        precondition(AppRequestParser.parse("findercreatefile://additional?typeID=evil&path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("findercreatefile://custom?typeID=json&path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("findercreatefile://create?type=exe&path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("findercreatefile://unknown?path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("https://create?type=txt&path=%2FUsers%2Ftester") == nil)
        print("Catalog, settings, and IPC tests passed.")
    }
}
