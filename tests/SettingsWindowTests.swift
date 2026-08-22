import AppKit

@main
struct SettingsWindowTests {
    static func main() {
        _ = NSApplication.shared
        var saved: Set<String>?
        let controller = FileTypeSettingsWindowController(
            types: FileTypeCatalog.additional,
            enabledIDs: ["json", "xml"],
            saveHandler: { saved = $0 },
            closeHandler: {}
        )
        guard let window = controller.window, let content = window.contentView else {
            fatalError("Settings window was not constructed")
        }
        precondition(window.styleMask.contains(.resizable))
        precondition(window.minSize == FileTypeSettingsWindowController.minimumSize)
        precondition(window.contentLayoutRect.size == FileTypeSettingsWindowController.defaultSize)

        window.setContentSize(FileTypeSettingsWindowController.minimumSize)
        content.layoutSubtreeIfNeeded()
        let views = descendants(of: content)
        let scrollViews = views.compactMap { $0 as? NSScrollView }
        let buttons = views.compactMap { $0 as? NSButton }
        let checkboxes = buttons.filter { $0.title.isEmpty }
        precondition(scrollViews.count == 1)
        precondition(checkboxes.count == 10)
        precondition(buttons.contains { $0.title == "保存" })
        precondition(buttons.contains { $0.title == "取消" })
        precondition(saved == nil)
        print("Settings window layout tests passed.")
    }

    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}
