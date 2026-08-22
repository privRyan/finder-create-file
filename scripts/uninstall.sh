#!/bin/bash
set -euo pipefail

DESTINATION="${INSTALL_DIR:-$HOME/Applications}/FinderCreateFile.app"
SUPPORT_DIRECTORY="${SUPPORT_DIRECTORY:-$HOME/Library/Application Support/FinderCreateFile}"
PURGE=0
ASSUME_YES=0
for argument in "$@"; do
    case "$argument" in
        --purge) PURGE=1 ;;
        --yes) ASSUME_YES=1 ;;
        *) echo "Unknown option: $argument" >&2; exit 64 ;;
    esac
done

if [[ "$ASSUME_YES" != "1" ]]; then
    prompt="Move FinderCreateFile.app to Trash"
    [[ "$PURGE" == "0" ]] || prompt="$prompt and purge its settings"
    read -r -p "$prompt? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
fi

trash_directory="${TRASH_DIR:-$HOME/.Trash}"
mkdir -p "$trash_directory"

if [[ -d "$DESTINATION" ]]; then
    app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    extension_path="$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex"
    extension_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$extension_path/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -z "$app_id" || "$extension_id" != "$app_id.FinderSync" ]]; then
        echo "Refusing to uninstall an app with unexpected bundle identifiers." >&2
        exit 73
    fi
    if [[ "${SKIP_REGISTRATION:-0}" != "1" ]]; then
        if ! /usr/bin/pluginkit -e ignore -i "$extension_id" 2>/dev/null; then
            echo "Warning: could not disable Finder extension $extension_id" >&2
        fi
        if ! /usr/bin/pluginkit -r "$extension_path" 2>/dev/null; then
            echo "Warning: could not remove Finder extension registration." >&2
        fi
        LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        if ! "$LSREGISTER" -u "$DESTINATION" 2>/dev/null; then
            echo "Warning: could not remove LaunchServices registration." >&2
        fi
        /usr/bin/pkill -x FinderCreateFile 2>/dev/null || true
    fi
    trash_target="$trash_directory/FinderCreateFile.app"
    if [[ -e "$trash_target" ]]; then
        trash_target="$trash_directory/FinderCreateFile-$(date +%Y%m%d-%H%M%S).app"
    fi
    /bin/mv "$DESTINATION" "$trash_target"
    [[ "${SKIP_REGISTRATION:-0}" == "1" ]] || /usr/bin/killall Finder 2>/dev/null || true
    echo "Moved app to Trash: $trash_target"
else
    echo "FinderCreateFile is not installed at $DESTINATION"
fi

if [[ "$PURGE" == "1" && -d "$SUPPORT_DIRECTORY" ]]; then
    support_target="$trash_directory/FinderCreateFile-Settings-$(date +%Y%m%d-%H%M%S)"
    /bin/mv "$SUPPORT_DIRECTORY" "$support_target"
    echo "Moved settings to Trash: $support_target"
elif [[ -d "$SUPPORT_DIRECTORY" ]]; then
    echo "Preserved settings: $SUPPORT_DIRECTORY (use --purge to remove them)"
fi
