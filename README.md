# Finder Create File

[简体中文](README.zh-CN.md)

Finder Create File adds a **New File** submenu to the background context menu in macOS Finder. It creates TXT, Markdown, valid blank Word/Excel documents, and selected built-in developer/text formats.

## Features

- Four consecutive menu items: `.txt`, `.md`, `.docx`, and `.xlsx`
- An allowlisted catalog for JSON, YAML (`.yaml` only), HTML, CSS, JavaScript, TypeScript, Python, Shell, XML, and CSV; users can enable or disable entries but cannot define extensions or import templates
- A file-type icon in both the menu and filename dialog
- Automatic extension handling and numbered names for conflicts
- Exclusive file creation: existing files are never overwritten, including concurrent requests
- Word/Excel templates bundled inside the app; the extension stores only a versioned list of enabled built-in type IDs
- Universal 2 binaries for Apple silicon and Intel Macs
- No network access or analytics

## Requirements and trust model

- macOS 13 or later
- Apple Command Line Tools (`xcode-select --install`)
- Bash, Swift compiler, and standard tools included with macOS

This repository does **not** distribute a Developer ID-signed or notarized executable. Build it locally from reviewed source. The default build uses an ad-hoc signature, which is suitable for local installation but not a substitute for Apple notarization.

The Finder Sync extension monitors `/` only so Finder offers the context menu everywhere. The app accepts creation requests only for existing directories resolved inside the current user's home directory or `/Volumes`, shows the resolved destination before creation, and uses exclusive filesystem creation to prevent overwrites.

Ad-hoc signed sandboxed extensions cannot reliably use an App Group: a [local probe](docs/APP-GROUP-PROBE.md) failed during sandbox initialization because the ad-hoc process had no valid Team ID/code identity. No cross-process settings store is needed here: the Finder extension owns the built-in-type selection in its standard sandboxed preferences and renders enabled entries itself. It sends only a fixed catalog ID and destination to the containing app, which independently validates both before showing the creation dialog.

## Build, verify, and install

```sh
git clone https://github.com/privRyan/finder-create-file.git
cd finder-create-file
make test
make install
```

The build creates `dist/FinderCreateFile.app` locally. Installation copies it to `~/Applications`, registers and enables the Finder extension, then restarts Finder. Replaced versions are preserved under `~/Library/Application Support/FinderCreateFile/Backups/updates/`. If the menu is still absent, enable **Finder 新建文件菜单** under **System Settings → General → Login Items & Extensions → Finder**.

The menu appears when right-clicking the background of an open Finder folder:

```text
新建文件
├── 文本文档 (.txt)
├── Markdown 文件 (.md)
├── Word 文档 (.docx)
├── Excel 工作簿 (.xlsx)
├── ─────────────
├── JSON 文件 (.json)      # when enabled
├── XML 文件 (.xml)        # when enabled
├── ─────────────
└── 管理文件类型…
```

The extra-type catalog has a stable order. JSON starts as `{}`, HTML gets a minimal HTML5 document, Shell gets a `#!/bin/sh` line, and XML gets a declaration plus `<root/>`; formats that are valid when empty are created empty. YAML is represented once as `.yaml`, avoiding duplicate `.yaml`/`.yml` choices.

## Other commands

```sh
make build       # build the app
make package     # make a local, ad-hoc-signed ZIP (do not publish as a notarized release)
make uninstall   # move the app to Trash, preserving settings
./scripts/uninstall.sh --purge  # also move settings to Trash
make clean       # remove generated artifacts
```

Build settings can be overridden when needed:

```sh
VERSION=1.1.0 BUILD_NUMBER=2 BUNDLE_ID_PREFIX=io.github.example make build
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" make build
```

A Developer ID build still needs notarization before public binary distribution. The project intentionally does not pretend that ad-hoc signing bypasses Gatekeeper.

## Template provenance

The blank Office templates are reproducibly generated during the build from the minimal, human-readable OOXML parts in `Resources/OfficeTemplates/`. They are zipped into `Contents/Resources/Templates/blank.docx` and `blank.xlsx`. No Microsoft artwork or template files are redistributed.

The application icon is drawn from original vector paths at build time. Runtime menu/dialog glyphs use macOS system symbols and are not bundled or redistributed.

## Security and limitations

See [SECURITY.md](SECURITY.md). The extension stores its versioned selection in the standard preferences for `io.github.privRyan.FinderCreateFile.FinderSync`; only fixed catalog IDs are stored. Unknown, duplicate, damaged, or out-of-version values are ignored, and catalog ordering always wins. The four defaults always remain consecutive; enabled extras appear after the first separator, and the management command stays last. Finder Sync is the macOS extension mechanism that can add a true background context menu; macOS may require the user to enable it manually. Network shares mounted outside `/Volumes` are intentionally rejected. UI text is currently Chinese.

## License

[MIT](LICENSE)
