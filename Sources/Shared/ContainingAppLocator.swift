import Foundation

enum ContainingAppLocator {
    static let appBundleName = "FinderCreateFile.app"
    static let extensionBundleName = "FinderCreateFileFinderSync.appex"

    static func locate(from extensionBundleURL: URL) -> URL? {
        guard extensionBundleURL.isFileURL else { return nil }
        let standardized = extensionBundleURL.standardizedFileURL
        guard standardized.path == extensionBundleURL.path else { return nil }
        let resolved = standardized.resolvingSymlinksInPath()
        guard resolved.path == standardized.path,
              resolved.lastPathComponent == extensionBundleName else { return nil }

        let plugIns = resolved.deletingLastPathComponent()
        let contents = plugIns.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard plugIns.lastPathComponent == "PlugIns",
              contents.lastPathComponent == "Contents",
              app.lastPathComponent == appBundleName else { return nil }
        return app
    }
}
