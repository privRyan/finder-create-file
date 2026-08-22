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

        let suiteName = "io.github.privRyan.FinderCreateFile.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { fatalError("Unable to create test defaults") }
        defaults.set(encoded, forKey: FileTypeSelection.defaultsKey)
        precondition(
            FileTypeSelection.enabledTypes(from: defaults.object(forKey: FileTypeSelection.defaultsKey)).map(\.id)
                == ["json", "csv"]
        )
        defaults.removePersistentDomain(forName: suiteName)

        let fixed = AppRequestParser.parse("findercreatefile://create?type=txt&path=%2FUsers%2Ftester")
        precondition(fixed == .createFixed(type: "txt", path: "/Users/tester"))
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
