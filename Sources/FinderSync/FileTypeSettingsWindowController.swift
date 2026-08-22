import AppKit

final class FileTypeSettingsWindowController: NSWindowController, NSWindowDelegate {
    static let defaultSize = NSSize(width: 560, height: 500)
    static let minimumSize = NSSize(width: 440, height: 320)

    private let selections: [(BuiltInFileType, NSButton)]
    private let saveHandler: (Set<String>) -> Void
    private let closeHandler: () -> Void

    init(
        types: [BuiltInFileType],
        enabledIDs: Set<String>,
        saveHandler: @escaping (Set<String>) -> Void,
        closeHandler: @escaping () -> Void
    ) {
        selections = types.map { type in
            let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            checkbox.state = enabledIDs.contains(type.id) ? .on : .off
            return (type, checkbox)
        }
        self.saveHandler = saveHandler
        self.closeHandler = closeHandler

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "管理文件类型"
        window.minSize = Self.minimumSize
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent(in: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func buildContent(in window: NSWindow) {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let heading = NSTextField(labelWithString: "管理文件类型")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)

        let explanation = NSTextField(wrappingLabelWithString:
            "默认的 TXT、Markdown、Word 和 Excel 始终保留。勾选的额外类型会直接显示在访达右键菜单中。"
        )
        explanation.maximumNumberOfLines = 0
        explanation.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let list = NSStackView()
        list.translatesAutoresizingMaskIntoConstraints = false
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 10

        for (type, checkbox) in selections {
            let label = NSTextField(wrappingLabelWithString: "\(type.displayName) (.\(type.fileExtension))")
            label.maximumNumberOfLines = 0
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let row = NSStackView(views: [checkbox, label])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(list)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false
        scrollView.documentView = documentView

        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        let save = NSButton(title: "保存", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        save.bezelStyle = .rounded
        let buttons = NSStackView(views: [cancel, save])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .horizontal
        buttons.spacing = 10

        for view in [heading, explanation, scrollView, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            heading.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            heading.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),

            explanation.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            explanation.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            explanation.trailingAnchor.constraint(equalTo: heading.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -16),

            buttons.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),

            documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor),

            list.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 14),
            list.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 14),
            list.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -14),
            list.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -14)
        ])
    }

    @objc private func save() {
        saveHandler(Set(selections.filter { $0.1.state == .on }.map { $0.0.id }))
        close()
    }

    @objc private func cancel() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        closeHandler()
    }
}
