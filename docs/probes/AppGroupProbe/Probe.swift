import Foundation

let group = "io.github.privRyan.FinderCreateFile.shared"
let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
print("container=\(container?.path ?? "nil")")
let defaults = UserDefaults(suiteName: group)
defaults?.set("probe", forKey: "value")
print("defaults=\(defaults?.string(forKey: "value") ?? "nil")")
