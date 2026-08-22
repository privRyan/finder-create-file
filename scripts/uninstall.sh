#!/bin/bash
set -euo pipefail

DESTINATION="${INSTALL_DIR:-$HOME/Applications}/FinderCreateFile.app"
EXTENSION_ID_DEFAULT="io.github.privRyan.FinderCreateFile.FinderSync"
extension_id="$EXTENSION_ID_DEFAULT"
PURGE=0
ASSUME_YES=0
for argument in "$@"; do
    case "$argument" in
        --purge) PURGE=1 ;;
        --yes) ASSUME_YES=1 ;;
        *) echo "Unknown option: $argument" >&2; exit 64 ;;
    esac
done

support_directory="$HOME/Library/Containers/$extension_id"
if [[ -n "${SUPPORT_DIRECTORY:-}" ]]; then
    echo "Unsupported SUPPORT_DIRECTORY environment variable; refusing ambiguous purge scope." >&2
    exit 64
fi
if [[ "${FCF_TEST_MODE:-0}" == "1" ]]; then
    support_directory="${FCF_TEST_SUPPORT_DIRECTORY:?FCF_TEST_SUPPORT_DIRECTORY is required in test mode}"
elif [[ -n "${FCF_TEST_SUPPORT_DIRECTORY:-}" ]]; then
    echo "FCF_TEST_SUPPORT_DIRECTORY requires FCF_TEST_MODE=1." >&2
    exit 64
fi
if [[ -L "$support_directory" ]]; then
    echo "Refusing a symlinked settings container: $support_directory" >&2
    exit 73
fi

if [[ "$ASSUME_YES" != "1" ]]; then
    prompt="Move FinderCreateFile.app to Trash"
    [[ "$PURGE" == "0" ]] || prompt="$prompt and purge its settings"
    read -r -p "$prompt? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
fi

trash_directory="${TRASH_DIR:-$HOME/.Trash}"
trash_timestamp="${TRASH_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
if [[ ! "$trash_timestamp" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    echo "Invalid TRASH_TIMESTAMP: $trash_timestamp" >&2
    exit 64
fi
mkdir -p "$trash_directory"

app_state="missing"
extension_path="$DESTINATION/Contents/PlugIns/FinderCreateFileFinderSync.appex"
if [[ -e "$DESTINATION" ]]; then
    app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    installed_extension_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$extension_path/Contents/Info.plist" 2>/dev/null || true)"
    if [[ ! -L "$DESTINATION" && ! -L "$extension_path" && \
          "$app_id" == "io.github.privRyan.FinderCreateFile" && "$installed_extension_id" == "$extension_id" ]] && \
       /usr/bin/codesign --verify --deep --strict "$DESTINATION" >/dev/null 2>&1; then
        app_state="official"
    else
        app_state="unexpected"
    fi
fi

registered_app_path=""
registered_extension_path=""
if [[ "$app_state" == "official" ]]; then
    trash_target="$trash_directory/FinderCreateFile.app"
    if [[ -e "$trash_target" ]]; then
        trash_base="$trash_directory/FinderCreateFile-$trash_timestamp"
        trash_target="$trash_base.app"
        trash_index=2
        while [[ -e "$trash_target" ]]; do
            trash_target="$trash_base-$trash_index.app"
            ((trash_index += 1))
        done
    fi
    /bin/mv "$DESTINATION" "$trash_target"
    registered_app_path="$trash_target"
    registered_extension_path="$trash_target/Contents/PlugIns/FinderCreateFileFinderSync.appex"
elif [[ "$app_state" == "unexpected" ]]; then
    echo "Refusing to move an app with unexpected bundle identifiers or signature." >&2
fi

if [[ "${SKIP_REGISTRATION:-0}" != "1" ]]; then
    PLUGIN_KIT="${PLUGIN_KIT:-/usr/bin/pluginkit}"
    LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
    PROCESS_KILLER="${PROCESS_KILLER:-/usr/bin/pkill}"
    FINDER_RESTARTER="${FINDER_RESTARTER:-/usr/bin/killall}"
    if ! "$PLUGIN_KIT" -e ignore -i "$extension_id" 2>/dev/null; then
        echo "Warning: could not disable Finder extension $extension_id" >&2
    fi
    if [[ -d "$registered_extension_path" ]] && ! "$PLUGIN_KIT" -r "$registered_extension_path" 2>/dev/null; then
        echo "Warning: could not remove Finder extension registration." >&2
    fi
    if [[ -d "$registered_app_path" ]] && ! "$LSREGISTER" -u "$registered_app_path" 2>/dev/null; then
        echo "Warning: could not remove LaunchServices registration." >&2
    fi
    "$PROCESS_KILLER" -x FinderCreateFile 2>/dev/null || true
    "$PROCESS_KILLER" -x FinderCreateFileFinderSync 2>/dev/null || true
    "$FINDER_RESTARTER" Finder 2>/dev/null || true
fi

if [[ "$app_state" == "unexpected" ]]; then
    exit 73
elif [[ "$app_state" == "official" ]]; then
    echo "Moved app to Trash: $trash_target"
else
    echo "FinderCreateFile is not installed at $DESTINATION"
fi

purge_incomplete=0
if [[ "$PURGE" == "1" && -d "$support_directory" ]]; then
    support_base="$trash_directory/FinderCreateFile-Settings-$trash_timestamp"
    support_target="$support_base"
    support_index=2
    while [[ -e "$support_target" ]]; do
        support_target="$support_base-$support_index"
        ((support_index += 1))
    done
    if /bin/mv "$support_directory" "$support_target"; then
        echo "Moved settings to Trash: $support_target"
    else
        echo "Warning: could not move the settings container to Trash: $support_directory" >&2
        purge_incomplete=1
    fi
elif [[ -d "$support_directory" ]]; then
    echo "Preserved settings: $support_directory (use --purge to remove them)"
fi

legacy_data_directory="${LEGACY_DATA_DIRECTORY:-$HOME/Library/Application Support/FinderCreateFile}"
if [[ "$PURGE" == "1" && -d "$legacy_data_directory" ]] && \
   [[ -n "$(/usr/bin/find "$legacy_data_directory" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "Warning: unrecognized legacy data was preserved at $legacy_data_directory; review it manually." >&2
fi

if [[ "$PURGE" == "1" && -e "$support_directory" ]]; then
    remaining="$(/usr/bin/find "$support_directory" -mindepth 1 \
        ! -name '.com.apple.containermanagerd.metadata.plist' -print -quit 2>/dev/null || true)"
    if [[ -n "$remaining" ]]; then
        echo "Warning: purge is incomplete; settings or data remain at $support_directory" >&2
        purge_incomplete=1
    else
        echo "Warning: only system-managed empty container metadata may remain at $support_directory" >&2
    fi
fi

[[ "$purge_incomplete" == "0" ]] || exit 74
