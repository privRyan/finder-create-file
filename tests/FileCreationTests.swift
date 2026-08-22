import Foundation
import Dispatch

@main
struct FileCreationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let templates = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let normalized = try FileCreator.normalizedTargetDirectory(root.path)
        precondition(normalized.path == root.resolvingSymlinksInPath().path)
        let txtName = try FileCreator.normalizedName("notes", type: "txt").filename
        let mdName = try FileCreator.normalizedName("README.MD", type: "md").filename
        precondition(txtName == "notes.txt")
        precondition(mdName == "README.MD")

        for invalid in ["", " ", ".", "..", ".txt", "a/b", "a:b"] {
            do {
                _ = try FileCreator.normalizedName(invalid, type: "txt")
                fatalError("Accepted invalid name: \(invalid)")
            } catch FileCreationError.invalidName {
                // Expected.
            }
        }

        let txt = try FileCreator.create(rawName: "sample", type: "txt", directory: normalized, template: nil)
        let md = try FileCreator.create(rawName: "README.md", type: "md", directory: normalized, template: nil)
        let docx = try FileCreator.create(rawName: "document", type: "docx", directory: normalized, template: templates.appendingPathComponent("blank.docx"))
        let xlsx = try FileCreator.create(rawName: "workbook", type: "xlsx", directory: normalized, template: templates.appendingPathComponent("blank.xlsx"))
        for url in [txt, md, docx, xlsx] { precondition(FileManager.default.fileExists(atPath: url.path)) }

        let duplicate = try FileCreator.create(rawName: "sample", type: "txt", directory: normalized, template: nil)
        precondition(duplicate.lastPathComponent == "sample 2.txt")

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "atomic-create-test", attributes: .concurrent)
        let lock = NSLock()
        var concurrentPaths = Set<String>()
        var concurrentError: Error?
        for _ in 0..<12 {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    let result = try FileCreator.create(rawName: "concurrent", type: "txt", directory: normalized, template: nil)
                    lock.lock(); concurrentPaths.insert(result.path); lock.unlock()
                } catch {
                    lock.lock(); concurrentError = error; lock.unlock()
                }
            }
        }
        group.wait()
        precondition(concurrentError == nil)
        precondition(concurrentPaths.count == 12)
        print("File creation behavior tests passed.")
    }
}
