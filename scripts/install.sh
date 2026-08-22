#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/FinderCreateFile.app" ]]; then
    SOURCE_APP="$SCRIPT_DIR/FinderCreateFile.app"
else
    SOURCE_APP="${1:-$SCRIPT_DIR/../dist/FinderCreateFile.app}"
fi
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
DESTINATION="$INSTALL_DIR/FinderCreateFile.app"

if [[ ! -d "$SOURCE_APP" ]]; then
    echo "FinderCreateFile.app not found. Run scripts/build.sh first." >&2
    exit 66
fi
/usr/bin/codesign --verify --deep --strict "$SOURCE_APP"
source_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")"
extension_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/PlugIns/FinderCreateFileFinderSync.appex/Contents/Info.plist")"
if [[ "$extension_id" != "$source_id.FinderSync" ]]; then
    echo "App and extension bundle identifiers do not match." >&2
    exit 65
fi

mkdir -p "$INSTALL_DIR"
backup=""
rollback() {
    status=$?
    trap - ERR
    if [[ -n "$backup" && -d "$backup" ]]; then
        [[ ! -e "$DESTINATION" ]] || /bin/rm -rf "$DESTINATION"
        /bin/mv "$backup" "$DESTINATION"
        echo "Installation failed; the previous app was restored." >&2
    elif [[ -e "$DESTINATION" ]]; then
        failed_directory="${FAILED_INSTALL_DIR:-$HOME/.Trash}"
        mkdir -p "$failed_directory"
        failed_target="$failed_directory/FinderCreateFile-failed-$(date +%Y%m%d-%H%M%S).app"
        /bin/mv "$DESTINATION" "$failed_target"
        echo "Installation failed; the incomplete app was moved to: $failed_target" >&2
    fi
    exit "$status"
}
trap rollback ERR

if [[ -e "$DESTINATION" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$existing_id" != "$source_id" ]]; then
        echo "Refusing to replace an unrelated item at $DESTINATION" >&2
        exit 73
    fi
    backup="$INSTALL_DIR/.FinderCreateFile.backup.$$"
    /bin/mv "$DESTINATION" "$backup"
fi
/usr/bin/ditto "$SOURCE_APP" "$DESTINATION"

if [[ "${SKIP_REGISTRATION:-0}" == "1" ]]; then
    registration_skipped=1
else
    registration_skipped=0
    LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
    "$LSREGISTER" -f "$DESTINATION"
    /usr/bin/pluginkit -a "$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex"
    /usr/bin/pluginkit -e use -i "$extension_id"
    /usr/bin/killall Finder 2>/dev/null || true
fi

if [[ -n "$backup" && -d "$backup" ]]; then
    backup_directory="${BACKUP_DIR:-$HOME/.Trash}"
    mkdir -p "$backup_directory"
    backup_target="$backup_directory/FinderCreateFile-previous-$(date +%Y%m%d-%H%M%S).app"
    /bin/mv "$backup" "$backup_target"
    echo "Previous version preserved at: $backup_target"
fi
trap - ERR

if [[ "$registration_skipped" == "1" ]]; then
    echo "Installed without registration: $DESTINATION"
else
    echo "Installed: $DESTINATION"
fi
echo "If the menu is missing, enable Finder 新建文件菜单 in System Settings > General > Login Items & Extensions > Finder."
