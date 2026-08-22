# Finder Create File

[简体中文](README.zh-CN.md)

Finder can create folders but has no built-in command for creating a new empty file. Finder Create File solves that gap by adding a **New File** submenu to the background context menu. It creates TXT, Markdown, valid blank Word/Excel/PowerPoint documents, and selected built-in developer/text formats.

## Features

- Five consecutive default menu items: `.txt`, `.md`, `.docx`, `.xlsx`, and `.pptx`
- An allowlisted catalog for JSON, YAML (`.yaml` only), HTML, CSS, JavaScript, TypeScript, Python, Shell, XML, and CSV; users can enable or disable entries but cannot define extensions or import templates
- A file-type icon in both the menu and filename dialog
- Automatic extension handling and numbered names for conflicts
- Exclusive file creation: existing files are never overwritten, including concurrent requests
- Word/Excel/PowerPoint templates bundled inside the app; the extension stores only a versioned list of enabled built-in type IDs
- A frontmost, resizable, scrollable settings window that remains reachable through Command-Tab while open
- Universal 2 binaries for Apple silicon and Intel Macs
- No network access or analytics

## Download, install, and use

1. Download `FinderCreateFile-v1.1.0-macos-universal.zip` and its matching `.sha256` file from [Releases](https://github.com/privRyan/finder-create-file/releases), then verify the published SHA-256 value.
2. Unzip it, Control-click **安装 FinderCreateFile.command**, and choose **Open**.
3. If needed, enable **Finder 新建文件菜单** under **System Settings → General → Login Items & Extensions → Finder**.
4. Control-click the background of a Finder folder, choose **新建文件**, or choose **管理文件类型…** to enable optional formats.

The prebuilt package and source build both target macOS 13 or later and contain Universal 2 executables for Apple silicon (`arm64`) and Intel (`x86_64`). The current release is tested in real Finder on Apple silicon; Intel support and the macOS 13 deployment target are build and static-verification gates, not claims of real-device testing.

Running, installing, and creating files require neither Command Line Tools nor Microsoft Office. Opening or editing `.docx`, `.xlsx`, or `.pptx` requires Microsoft Office or another compatible application. The project adds no Login Item; Finder loads the extension when needed.

The downloadable app is ad-hoc signed, not Developer ID signed or Apple-notarized. On first open, macOS may require Control-click → Open or approval in **Privacy & Security**. The installer does not remove quarantine attributes or disable Gatekeeper.

## Build from source

Building requires Apple Command Line Tools (`xcode-select --install`), including Swift and Clang. Runtime use does not.

The Finder Sync extension monitors `/` only so Finder offers the context menu everywhere. The app accepts creation requests only for existing directories resolved inside the current user's home directory or `/Volumes`, shows the resolved destination before creation, and uses exclusive filesystem creation to prevent overwrites.

Ad-hoc signed sandboxed extensions cannot reliably use an App Group: a [local probe](docs/APP-GROUP-PROBE.md) failed during sandbox initialization because the ad-hoc process had no valid Team ID/code identity. No cross-process settings store is needed here: the Finder extension owns the built-in-type selection in its standard sandboxed preferences and renders enabled entries itself. It sends only a fixed catalog ID and destination to the containing app, which independently validates both before showing the creation dialog.

```sh
git clone https://github.com/privRyan/finder-create-file.git
cd finder-create-file
make test
make install
```

The source build creates `dist/FinderCreateFile.app`. Installation stages and verifies it beside `~/Applications`, registers and enables the Finder extension, then refreshes Finder. A simple atomic lock rejects concurrent installers. Catchable signals clean staging and the lock; if registration fails after placement, the complete app is retained and rerunning `make install` retries registration. A stale lock is never guessed away—inspect `.FinderCreateFile.install.lock`, then remove that exact directory manually if no installer is running.

Automatic in-place upgrades are intentionally unsupported: the installer never moves, backs up, deletes, or overwrites an existing app. If the existing app has the same bundle ID, valid signature, and complete bundle fingerprint (all architectures and the embedded extension included), installation only retries registration. If it is a different build, run `make uninstall` first (the old app is moved to Trash and remains recoverable), then run `make install`.

The menu appears when right-clicking the background of an open Finder folder:

```text
新建文件
├── 文本文档 (.txt)
├── Markdown 文件 (.md)
├── Word 文档 (.docx)
├── Excel 工作簿 (.xlsx)
├── PowerPoint 演示文稿 (.pptx)
├── JSON 文件 (.json)      # when enabled
├── XML 文件 (.xml)        # when enabled
└── 管理文件类型…
```

The extra-type catalog has a stable order. JSON starts as `{}`, HTML gets a minimal HTML5 document, Shell gets a `#!/bin/sh` line, and XML gets a declaration plus `<root/>`; formats that are valid when empty are created empty. YAML is represented once as `.yaml`, avoiding duplicate `.yaml`/`.yml` choices.

## Other commands

```sh
make build       # build the app
make package     # build the ad-hoc-signed Universal 2 distribution ZIP
make uninstall   # unregister, move the app to Trash, and preserve settings
./scripts/uninstall.sh --purge  # also move the extension settings container to Trash
make clean       # remove generated artifacts
```

Build settings can be overridden when needed:

```sh
VERSION=1.1.0 BUILD_NUMBER=3 BUNDLE_ID_PREFIX=io.github.example make build
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" make build
```

A polished drag-to-`/Applications` distribution requires a Developer ID signature and Apple notarization. A Developer ID build still needs notarization before public binary distribution; the project intentionally does not pretend that ad-hoc signing bypasses Gatekeeper.

## Template provenance

The blank Office templates are reproducibly generated from auditable OOXML parts in `Resources/OfficeTemplates/`. They are zipped into `blank.docx`, `blank.xlsx`, and a one-slide, 16:9, object-free `blank.pptx`. No Microsoft artwork or template files are redistributed.

The application icon is drawn from original vector paths at build time. Runtime menu/dialog glyphs use macOS system symbols and are not bundled or redistributed.

## Security and limitations

See [SECURITY.md](SECURITY.md). The extension stores only versioned, fixed catalog IDs. Unknown, duplicate, damaged, or out-of-version values are ignored. All menu entries are continuous, with the five defaults first and management last. The sandboxed extension validates its fixed containing-app hierarchy. Finder Sync may require manual enablement. Network shares mounted outside `/Volumes` are intentionally rejected. UI text is currently Chinese.

Normal uninstall unregisters the extension, moves the app to Trash, and preserves selected types. `--purge` also attempts to move the official settings container to Trash. System-managed empty container metadata may remain; unknown legacy data is reported and preserved for manual review rather than guessed away.

## License

[MIT](LICENSE)
