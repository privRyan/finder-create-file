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
        precondition(String(data: FileTypeCatalog.type(id: "json")!.strategy.data, encoding: .utf8) == "{}\n")
        precondition(String(data: FileTypeCatalog.type(id: "xml")!.strategy.data, encoding: .utf8)?.contains("<root/>") == true)
        precondition(String(data: FileTypeCatalog.type(id: "html")!.strategy.data, encoding: .utf8)?.contains("<!doctype html>") == true)

        let untrusted = Data("{\"version\":1,\"enabledTypeIDs\":[\"xml\",\"unknown\",\"json\",\"xml\",\"css\"]}".utf8)
        precondition(FileTypeSettingsStore.enabledTypes(from: untrusted).map(\.id) == ["json", "css", "xml"])
        let future = Data("{\"version\":2,\"enabledTypeIDs\":[\"json\"]}".utf8)
        precondition(FileTypeSettingsStore.enabledTypes(from: future).isEmpty)
        precondition(FileTypeSettingsStore.enabledTypes(from: Data("bad".utf8)).isEmpty)

        let encoded = try FileTypeSettingsStore.encodedSettings(enabledIDs: Set(["csv", "json", "unknown", "csv"]))
        precondition(FileTypeSettingsStore.enabledTypes(from: encoded).map(\.id) == ["json", "csv"])

        let fixed = AppRequestParser.parse("findercreatefile://create?type=txt&path=%2FUsers%2Ftester")
        precondition(fixed == .createFixed(type: "txt", path: "/Users/tester"))
        let additional = AppRequestParser.parse("findercreatefile://custom?type=evil&path=%2FUsers%2Ftester")
        precondition(additional == .createAdditional(path: "/Users/tester"))
        precondition(AppRequestParser.parse("findercreatefile://create?type=exe&path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("findercreatefile://unknown?path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("https://create?type=txt&path=%2FUsers%2Ftester") == nil)
        precondition(AppRequestParser.parse("findercreatefile://manage?type=evil") == .manageTypes)
        print("Catalog, settings, and IPC tests passed.")
    }
}
