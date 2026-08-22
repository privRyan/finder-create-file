#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/FinderCreateFile.app" ]]; then
    SOURCE_APP="$SCRIPT_DIR/FinderCreateFile.app"
else
    SOURCE_APP="${1:-$SCRIPT_DIR/../dist/FinderCreateFile.app}"
fi

if [[ -n "${ROLLBACK_TMPDIR:-}" ]]; then
    echo "ROLLBACK_TMPDIR is no longer supported; transactions must stay inside INSTALL_DIR." >&2
    exit 64
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

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
mkdir -p "$INSTALL_DIR"
if [[ ! -d "$INSTALL_DIR" || ! -w "$INSTALL_DIR" ]]; then
    echo "Install directory is not writable: $INSTALL_DIR" >&2
    exit 73
fi
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd -P)"
DESTINATION="$INSTALL_DIR/FinderCreateFile.app"
LOCK_DIR="$INSTALL_DIR/.FinderCreateFile.install.lock"
TRANSACTION_DIR="$LOCK_DIR/transaction"
STAGED_APP="$TRANSACTION_DIR/staged.app"
PREVIOUS_APP="$TRANSACTION_DIR/previous.app"

LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
PLUGIN_KIT="${PLUGIN_KIT:-/usr/bin/pluginkit}"
PROCESS_KILLER="${PROCESS_KILLER:-/usr/bin/pkill}"
FINDER_RESTARTER="${FINDER_RESTARTER:-/usr/bin/killall}"
OLD_APP_MOVER="${OLD_APP_MOVER:-/bin/mv}"
COMMITTED_CLEANER="${COMMITTED_CLEANER:-/bin/rm}"

old_app_moved=0
new_app_installed=0
committed=0
registration_started=0
previous_extension_enabled=0
rolling_back=0

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if [[ -L "$LOCK_DIR" || ! -d "$LOCK_DIR" ]]; then
        echo "Unsafe install lock exists: $LOCK_DIR" >&2
    else
        owner="$(/bin/cat "$LOCK_DIR/owner.pid" 2>/dev/null || true)"
        if [[ "$owner" =~ ^[0-9]+$ ]] && /bin/kill -0 "$owner" 2>/dev/null; then
            echo "Another FinderCreateFile installation is running (PID $owner)." >&2
        else
            echo "A stale or interrupted installation remains at: $LOCK_DIR" >&2
            echo "Inspect its transaction/previous.app before manually removing the lock; the installer will not guess." >&2
        fi
    fi
    exit 75
fi

rollback() {
    local status="${1:-1}"
    trap - ERR INT TERM HUP
    if [[ "$rolling_back" == "1" ]]; then
        exit "$status"
    fi
    rolling_back=1

    if [[ "$committed" != "1" ]]; then
        if [[ "$registration_started" == "1" && "$new_app_installed" == "1" ]]; then
            "$PLUGIN_KIT" -e ignore -i "$extension_id" 2>/dev/null || true
            "$PLUGIN_KIT" -r "$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex" 2>/dev/null || true
            "$LSREGISTER" -u "$DESTINATION" 2>/dev/null || true
        fi

        if [[ "$old_app_moved" == "1" ]]; then
            if [[ ! -d "$PREVIOUS_APP" ]]; then
                echo "Rollback could not find the previous app; transaction preserved at $LOCK_DIR" >&2
                exit "$status"
            fi
            if [[ "$new_app_installed" == "1" && -e "$DESTINATION" ]]; then
                /bin/rm -rf "$DESTINATION"
                new_app_installed=0
            fi
            /bin/mv "$PREVIOUS_APP" "$DESTINATION"
            old_app_moved=0
            if [[ "$registration_started" == "1" ]]; then
                "$LSREGISTER" -f "$DESTINATION" 2>/dev/null || true
                "$PLUGIN_KIT" -a "$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex" 2>/dev/null || true
                if [[ "$previous_extension_enabled" == "1" ]]; then
                    "$PLUGIN_KIT" -e use -i "$extension_id" 2>/dev/null || true
                else
                    "$PLUGIN_KIT" -e ignore -i "$extension_id" 2>/dev/null || true
                fi
            fi
            echo "Installation failed; the previous app was restored." >&2
        elif [[ "$new_app_installed" == "1" && -e "$DESTINATION" ]]; then
            /bin/rm -rf "$DESTINATION"
            new_app_installed=0
        fi
    fi

    [[ "$registration_started" == "0" ]] || "$FINDER_RESTARTER" Finder 2>/dev/null || true
    /bin/rm -rf "$LOCK_DIR"
    exit "$status"
}
on_error() { local status=$?; rollback "$status"; }
on_int() { rollback 130; }
on_term() { rollback 143; }
on_hup() { rollback 129; }
trap on_error ERR
trap on_int INT
trap on_term TERM
trap on_hup HUP

/bin/echo "$$" > "$LOCK_DIR/owner.pid"
mkdir "$TRANSACTION_DIR"
/usr/bin/ditto "$SOURCE_APP" "$STAGED_APP"
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"
staged_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$STAGED_APP/Contents/Info.plist")"
if [[ "$staged_id" != "$source_id" ]]; then
    echo "Staged app bundle identifier changed unexpectedly." >&2
    false
fi

if [[ -e "$DESTINATION" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$existing_id" != "$source_id" ]]; then
        echo "Refusing to replace an unrelated item at $DESTINATION" >&2
        false
    fi
    if [[ "${SKIP_REGISTRATION:-0}" != "1" ]] && \
       "$PLUGIN_KIT" -m -v -i "$extension_id" 2>/dev/null | /usr/bin/grep -q '^+'; then
        previous_extension_enabled=1
    fi
    "$OLD_APP_MOVER" "$DESTINATION" "$PREVIOUS_APP"
    old_app_moved=1
fi

case "${AFTER_OLD_MOVE_SIGNAL:-none}" in
    none) ;;
    INT|TERM|HUP) /bin/kill -s "$AFTER_OLD_MOVE_SIGNAL" "$$" ;;
    *) echo "Invalid AFTER_OLD_MOVE_SIGNAL test hook." >&2; false ;;
esac

if [[ "${LOCK_HOLD_SECONDS:-0}" != "0" ]]; then
    /bin/sleep "$LOCK_HOLD_SECONDS"
fi
/bin/mv "$STAGED_APP" "$DESTINATION"
new_app_installed=1

if [[ "${SKIP_REGISTRATION:-0}" == "1" ]]; then
    registration_skipped=1
else
    registration_skipped=0
    registration_started=1
    "$PROCESS_KILLER" -x FinderCreateFile 2>/dev/null || true
    "$LSREGISTER" -f "$DESTINATION"
    "$PLUGIN_KIT" -a "$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex"
    "$PLUGIN_KIT" -e use -i "$extension_id"
    "$FINDER_RESTARTER" Finder 2>/dev/null || true
fi

committed=1
trap - ERR INT TERM HUP
/bin/echo committed > "$LOCK_DIR/committed" 2>/dev/null || \
    echo "Warning: could not mark the completed transaction." >&2
if ! "$COMMITTED_CLEANER" -rf "$LOCK_DIR"; then
    echo "Warning: installation succeeded, but transaction cleanup failed: $LOCK_DIR" >&2
fi

if [[ "$registration_skipped" == "1" ]]; then
    echo "Installed without registration: $DESTINATION"
else
    echo "Installed: $DESTINATION"
fi
echo "If the menu is missing, enable Finder 新建文件菜单 in System Settings > General > Login Items & Extensions > Finder."
