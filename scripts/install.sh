#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/FinderCreateFile.app" ]]; then
    SOURCE_APP="$SCRIPT_DIR/FinderCreateFile.app"
else
    SOURCE_APP="${1:-$SCRIPT_DIR/../dist/FinderCreateFile.app}"
fi
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
source_cdhash="$(/usr/bin/codesign -dvvv "$SOURCE_APP" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -1)"
[[ -n "$source_cdhash" ]] || { echo "Could not fingerprint the source app." >&2; exit 65; }

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
mkdir -p "$INSTALL_DIR"
if [[ ! -d "$INSTALL_DIR" || ! -w "$INSTALL_DIR" ]]; then
    echo "Install directory is not writable: $INSTALL_DIR" >&2
    exit 73
fi
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd -P)"
DESTINATION="$INSTALL_DIR/FinderCreateFile.app"
LOCK_DIR="$INSTALL_DIR/.FinderCreateFile.install.lock"
STAGE_DIR=""

LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
PLUGIN_KIT="${PLUGIN_KIT:-/usr/bin/pluginkit}"
PROCESS_KILLER="${PROCESS_KILLER:-/usr/bin/pkill}"
FINDER_RESTARTER="${FINDER_RESTARTER:-/usr/bin/killall}"
COPY_TOOL="${COPY_TOOL:-/usr/bin/ditto}"
installed_app_ready=0

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    owner="$(/bin/cat "$LOCK_DIR/owner.pid" 2>/dev/null || true)"
    if [[ "$owner" =~ ^[0-9]+$ ]] && /bin/kill -0 "$owner" 2>/dev/null; then
        echo "Another FinderCreateFile installation is running (PID $owner)." >&2
    else
        echo "A stale install lock remains at $LOCK_DIR; inspect it, then remove that lock directory manually." >&2
    fi
    exit 75
fi

cleanup_work() {
    trap - ERR
    trap '' INT TERM HUP
    if [[ -n "$STAGE_DIR" ]]; then
        case "$STAGE_DIR" in
            "$INSTALL_DIR"/.FinderCreateFile.stage.*) /bin/rm -rf "$STAGE_DIR" ;;
            *) echo "Refusing to clean unexpected staging path: $STAGE_DIR" >&2 ;;
        esac
    fi
    /bin/rm -rf "$LOCK_DIR"
}

installation_failed() {
    local status="${1:-1}"
    cleanup_work
    if [[ "$installed_app_ready" == "1" ]]; then
        echo "Installation did not finish registration. The complete app was retained at $DESTINATION; rerun install to retry." >&2
    fi
    exit "$status"
}
on_error() { local status=$?; installation_failed "$status"; }
on_int() { installation_failed 130; }
on_term() { installation_failed 143; }
on_hup() { installation_failed 129; }
trap on_error ERR
trap on_int INT
trap on_term TERM
trap on_hup HUP
/bin/echo "$$" > "$LOCK_DIR/owner.pid"

if [[ -e "$DESTINATION" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$existing_id" != "$source_id" ]]; then
        echo "Refusing to touch an unrelated item at $DESTINATION" >&2
        false
    fi
    if ! /usr/bin/codesign --verify --deep --strict "$DESTINATION" >/dev/null 2>&1; then
        echo "The installed app is not a valid copy. Move it aside manually, then rerun install." >&2
        false
    fi
    existing_cdhash="$(/usr/bin/codesign -dvvv "$DESTINATION" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -1)"
    if [[ -z "$existing_cdhash" || "$existing_cdhash" != "$source_cdhash" ]]; then
        echo "A different FinderCreateFile build is already installed." >&2
        echo "Run scripts/uninstall.sh first (it moves the app to Trash), then run install again." >&2
        false
    fi
    installed_app_ready=1
else
    STAGE_DIR="$(/usr/bin/mktemp -d "$INSTALL_DIR/.FinderCreateFile.stage.XXXXXX")"
    STAGED_APP="$STAGE_DIR/FinderCreateFile.app"
    "$COPY_TOOL" "$SOURCE_APP" "$STAGED_APP"
    /usr/bin/codesign --verify --deep --strict "$STAGED_APP"
    staged_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$STAGED_APP/Contents/Info.plist")"
    staged_cdhash="$(/usr/bin/codesign -dvvv "$STAGED_APP" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -1)"
    if [[ "$staged_id" != "$source_id" || "$staged_cdhash" != "$source_cdhash" ]]; then
        echo "Staged app verification failed." >&2
        false
    fi
    case "${AFTER_COPY_SIGNAL:-none}" in
        none) ;;
        INT|TERM|HUP) /bin/kill -s "$AFTER_COPY_SIGNAL" "$$" ;;
        *) echo "Invalid AFTER_COPY_SIGNAL test hook." >&2; false ;;
    esac
    [[ "${LOCK_HOLD_SECONDS:-0}" == "0" ]] || /bin/sleep "$LOCK_HOLD_SECONDS"
    /bin/mv "$STAGED_APP" "$DESTINATION"
    installed_app_ready=1
fi

if [[ "${SKIP_REGISTRATION:-0}" == "1" ]]; then
    registration_skipped=1
else
    registration_skipped=0
    "$PROCESS_KILLER" -x FinderCreateFile 2>/dev/null || true
    "$LSREGISTER" -f "$DESTINATION"
    "$PLUGIN_KIT" -a "$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex"
    "$PLUGIN_KIT" -e use -i "$extension_id"
    "$FINDER_RESTARTER" Finder 2>/dev/null || true
fi

trap - ERR INT TERM HUP
cleanup_work
if [[ "$registration_skipped" == "1" ]]; then
    echo "Installed without registration: $DESTINATION"
else
    echo "Installed: $DESTINATION"
fi
echo "If the menu is missing, enable Finder 新建文件菜单 in System Settings > General > Login Items & Extensions > Finder."
