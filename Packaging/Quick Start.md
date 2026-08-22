# Finder Create File — Quick Start

Finder normally creates folders but has no built-in command for making a new empty file. Finder Create File adds that command to a folder's background context menu.

## Install

1. Unzip the download.
2. Control-click **安装 FinderCreateFile.command** and choose **Open**. Because this build is ad-hoc signed and not notarized, macOS may require this explicit first-open approval or approval in **System Settings → Privacy & Security**.
3. Open **System Settings → General → Login Items & Extensions → Finder** and enable **Finder 新建文件菜单** if it is not already enabled.
4. In Finder, Control-click the background of a folder and choose **新建文件**.

The app does not add a Login Item. It runs only when Finder invokes it. macOS 13 or later is required; both Apple silicon (`arm64`) and Intel (`x86_64`) are included. Command Line Tools and Microsoft Office are not required to install or create files. A compatible application is required to open or edit Word, Excel, or PowerPoint files.

## Uninstall

Control-click **卸载 FinderCreateFile.command**, choose **Open**, and confirm. Normal uninstall moves the app to Trash and preserves your selected file types. Run it from Terminal with `--purge` only when you also want to move the extension's settings container to Trash. Unrecognized legacy data is never removed automatically.

This package is ad-hoc signed, not Developer ID signed or Apple-notarized. It does not disable Gatekeeper or remove quarantine attributes.
