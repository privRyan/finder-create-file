import AppKit
import ServiceManagement

enum FinderExtensionStatus {
    static var isEnabled: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-i", "io.github.privRyan.FinderCreateFile.FinderSync"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return false }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.split(separator: "\n").contains { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("+    io.github.privRyan.FinderCreateFile.FinderSync(")
        }
    }
}

final class AppDragView: NSView, NSDraggingSource {
    private var dragStart: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 10
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1

        let icon = NSImageView(frame: NSRect(x: 12, y: 10, width: 42, height: 42))
        icon.image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        addSubview(icon)
        let label = NSTextField(labelWithString: L10n.text("FinderCreateFile.app  ·  拖到“登录时打开”", "FinderCreateFile.app  ·  Drag to Open at Login"))
        label.frame = NSRect(x: 66, y: 19, width: 350, height: 24)
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart,
              hypot(start.x - convert(event.locationInWindow, from: nil).x,
                    start.y - convert(event.locationInWindow, from: nil).y) > 4 else { return }
        dragStart = nil
        let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
        item.setDraggingFrame(NSRect(x: 12, y: 10, width: 42, height: 42),
                              contents: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

final class SetupWindowController: NSWindowController, NSWindowDelegate {
    private let loginMissing: Bool
    private let finderMissing: Bool

    init(loginMissing: Bool, finderMissing: Bool) {
        self.loginMissing = loginMissing
        self.finderMissing = finderMissing
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: loginMissing ? 300 : 220),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L10n.text("完成 Finder 新建文件设置", "Finish Finder Create File Setup")
        window.center()
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let window else { return }
        let view = NSView(frame: window.contentView!.bounds)
        window.contentView = view
        let title = NSTextField(labelWithString: L10n.text("还需要完成系统设置", "Finish Setup in System Settings"))
        title.font = .boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 24, y: view.bounds.height - 52, width: 440, height: 26)
        view.addSubview(title)

        var instructions: [String] = []
        if loginMissing { instructions.append(L10n.text("在“登录时打开”中添加本应用，登录后即可自动启动。", "Add this app to Open at Login to start it when you sign in.")) }
        if finderMissing { instructions.append(L10n.text("在“登录项与扩展 → 访达”中开启“Finder 新建文件菜单”。", "Enable Finder Create File Menu under Login Items & Extensions → Finder.")) }
        let detail = NSTextField(wrappingLabelWithString: instructions.joined(separator: "\n"))
        detail.frame = NSRect(x: 24, y: view.bounds.height - 116, width: 440, height: 56)
        view.addSubview(detail)

        if loginMissing {
            let drag = AppDragView(frame: NSRect(x: 24, y: 100, width: 442, height: 62))
            view.addSubview(drag)
        }

        let settings = NSButton(title: L10n.text("打开系统设置", "Open System Settings"), target: self, action: #selector(openSettings))
        settings.frame = NSRect(x: 316, y: 24, width: 150, height: 32)
        settings.bezelStyle = .rounded
        view.addSubview(settings)
        if loginMissing {
            let enable = NSButton(title: L10n.text("启用登录自启", "Enable at Login"), target: self, action: #selector(enableLogin))
            enable.frame = NSRect(x: 164, y: 24, width: 142, height: 32)
            enable.bezelStyle = .rounded
            view.addSubview(enable)
        }
        let skip = NSButton(title: L10n.text("跳过", "Skip"), target: self, action: #selector(skip))
        skip.frame = NSRect(x: loginMissing ? 70 : 222, y: 24, width: 84, height: 32)
        skip.bezelStyle = .rounded
        view.addSubview(skip)
    }

    @objc private func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func enableLogin() {
        do {
            try SMAppService.mainApp.register()
            SMAppService.openSystemSettingsLoginItems()
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.text("无法自动添加登录项", "Could Not Add Login Item")
            alert.informativeText = L10n.text("可以在系统设置中将 App 图标拖到“登录时打开”。\n\n", "You can drag the app tile into Open at Login in System Settings.\n\n") + error.localizedDescription
            alert.runModal()
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc private func skip() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
