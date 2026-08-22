#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_DIR/dist/FinderCreateFile.app"

for script in "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/tests/*.sh; do
    /bin/bash -n "$script"
done

if [[ ! -d "$APP" ]]; then
    "$PROJECT_DIR/scripts/build.sh"
fi

/usr/bin/plutil -lint "$APP/Contents/Info.plist" "$APP/Contents/PlugIns/FinderCreateFileFinderSync.appex/Contents/Info.plist"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
/usr/bin/unzip -tq "$APP/Contents/Resources/Templates/blank.docx"
/usr/bin/unzip -tq "$APP/Contents/Resources/Templates/blank.xlsx"
for xml in \
    "$PROJECT_DIR/Resources/OfficeTemplates/docx/[Content_Types].xml" \
    "$PROJECT_DIR/Resources/OfficeTemplates/docx/_rels/.rels" \
    "$PROJECT_DIR/Resources/OfficeTemplates/docx/word/document.xml" \
    "$PROJECT_DIR/Resources/OfficeTemplates/xlsx/[Content_Types].xml" \
    "$PROJECT_DIR/Resources/OfficeTemplates/xlsx/_rels/.rels" \
    "$PROJECT_DIR/Resources/OfficeTemplates/xlsx/xl/workbook.xml" \
    "$PROJECT_DIR/Resources/OfficeTemplates/xlsx/xl/_rels/workbook.xml.rels" \
    "$PROJECT_DIR/Resources/OfficeTemplates/xlsx/xl/worksheets/sheet1.xml"; do
    /usr/bin/xmllint --noout "$xml"
done
docx_entries="$(/usr/bin/unzip -Z1 "$APP/Contents/Resources/Templates/blank.docx")"
xlsx_entries="$(/usr/bin/unzip -Z1 "$APP/Contents/Resources/Templates/blank.xlsx")"
/usr/bin/grep -qx 'word/document.xml' <<< "$docx_entries"
/usr/bin/grep -qx 'xl/worksheets/sheet1.xml' <<< "$xlsx_entries"
app_archs="$(/usr/bin/lipo -archs "$APP/Contents/MacOS/FinderCreateFile")"
extension_archs="$(/usr/bin/lipo -archs "$APP/Contents/PlugIns/FinderCreateFileFinderSync.appex/Contents/MacOS/FinderCreateFileFinderSync")"
/usr/bin/grep -q 'arm64 x86_64\|x86_64 arm64' <<< "$app_archs"
/usr/bin/grep -q 'arm64 x86_64\|x86_64 arm64' <<< "$extension_archs"
extension_symbols="$(/usr/bin/nm -m "$APP/Contents/PlugIns/FinderCreateFileFinderSync.appex/Contents/MacOS/FinderCreateFileFinderSync")"
/usr/bin/grep -q '_NSExtensionMain' <<< "$extension_symbols"
app_linked_libraries="$(/usr/bin/otool -L "$APP/Contents/MacOS/FinderCreateFile")"
if /usr/bin/grep -q '/Carbon.framework/' <<< "$app_linked_libraries"; then
    echo "Main app unexpectedly links Carbon.framework" >&2
    exit 1
fi
for executable in \
    "$APP/Contents/MacOS/FinderCreateFile" \
    "$APP/Contents/PlugIns/FinderCreateFileFinderSync.appex/Contents/MacOS/FinderCreateFileFinderSync"; do
    build_info="$(/usr/bin/vtool -show-build "$executable")"
    /usr/bin/grep -q 'minos 13.0' <<< "$build_info"
done

if /usr/bin/grep -R -n '/Users/' "$PROJECT_DIR/Sources" "$PROJECT_DIR/Config" "$PROJECT_DIR/Resources" "$PROJECT_DIR/scripts"; then
    echo "Absolute user path found" >&2
    exit 1
fi
for type in txt md docx xlsx; do
    /usr/bin/grep -q "create(type: \"$type\")" "$PROJECT_DIR/Sources/FinderSync/FinderSyncExtension.swift"
done
/usr/bin/grep -q 'Bundle.main.resourceURL' "$PROJECT_DIR/Sources/App/AppMain.swift"
if /usr/bin/grep -R -n 'NSOpenPanel\|extensionField\|importTemplate\|更多文件类型' "$PROJECT_DIR/Sources"; then
    echo "Arbitrary custom type or template input found" >&2
    exit 1
fi
/usr/bin/grep -q 'static let currentVersion = 1' "$PROJECT_DIR/Sources/Shared/FileTypeCatalog.swift"
/usr/bin/grep -q 'FileTypeCatalog.additional.filter' "$PROJECT_DIR/Sources/Shared/FileTypeCatalog.swift"
menu_source="$PROJECT_DIR/Sources/FinderSync/FinderSyncExtension.swift"
txt_line="$(/usr/bin/grep -n '文本文档 (.txt)' "$menu_source" | /usr/bin/cut -d: -f1)"
md_line="$(/usr/bin/grep -n 'Markdown 文件 (.md)' "$menu_source" | /usr/bin/cut -d: -f1)"
docx_line="$(/usr/bin/grep -n 'Word 文档 (.docx)' "$menu_source" | /usr/bin/cut -d: -f1)"
xlsx_line="$(/usr/bin/grep -n 'Excel 工作簿 (.xlsx)' "$menu_source" | /usr/bin/cut -d: -f1)"
first_separator_line="$(/usr/bin/grep -n 'submenu.addItem(.separator())' "$menu_source" | /usr/bin/head -1 | /usr/bin/cut -d: -f1)"
manage_line="$(/usr/bin/grep -n '管理文件类型…' "$menu_source" | /usr/bin/head -1 | /usr/bin/cut -d: -f1)"
(( txt_line < md_line && md_line < docx_line && docx_line < xlsx_line && xlsx_line < first_separator_line && first_separator_line < manage_line ))
/usr/bin/grep -q 'UserDefaults.standard.object' "$menu_source"
/usr/bin/grep -q 'FileTypeSelection.storedValue' "$menu_source"
/usr/bin/grep -q 'private static let delegate = AppDelegate()' "$PROJECT_DIR/Sources/App/AppMain.swift"
/usr/bin/grep -q 'withApplicationAt: containingApp' "$menu_source"
/usr/bin/grep -q 'appBundle.bundleIdentifier == String(extensionID.dropLast' "$menu_source"
/usr/bin/grep -q 'isExecutableFile(atPath: executable.path)' "$menu_source"
/usr/bin/grep -q 'func application(_ application: NSApplication, open urls: \[URL\])' \
    "$PROJECT_DIR/Sources/App/AppMain.swift"

if VERSION='../escape' "$PROJECT_DIR/scripts/package.sh" >/dev/null 2>&1; then
    echo "Unsafe package VERSION was accepted" >&2
    exit 1
fi

/usr/bin/clang -target "$(uname -m)-apple-macos13.0" -mmacosx-version-min=13.0 -c \
    "$PROJECT_DIR/Sources/Shared/ExclusiveCreate.c" \
    -o "$PROJECT_DIR/.build/ExclusiveCreate-test.o"
/usr/bin/swiftc -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
    "$PROJECT_DIR/Sources/Shared/FileCreation.swift" \
    "$PROJECT_DIR/Sources/Shared/FileTypeCatalog.swift" \
    "$PROJECT_DIR/tests/FileCreationTests.swift" \
    "$PROJECT_DIR/.build/ExclusiveCreate-test.o" \
    -o "$PROJECT_DIR/.build/file-creation-tests"
"$PROJECT_DIR/.build/file-creation-tests" \
    "$PROJECT_DIR/.build/test-data" \
    "$APP/Contents/Resources/Templates"

/usr/bin/swiftc -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
    -framework AppKit \
    "$PROJECT_DIR/Sources/Shared/FileCreation.swift" \
    "$PROJECT_DIR/Sources/Shared/FileTypeCatalog.swift" \
    "$PROJECT_DIR/tests/CatalogTests.swift" \
    "$PROJECT_DIR/.build/ExclusiveCreate-test.o" \
    -o "$PROJECT_DIR/.build/catalog-tests"
"$PROJECT_DIR/.build/catalog-tests"

install_test_dir="$PROJECT_DIR/.build/install-test"
rm -rf "$install_test_dir"
mkdir -p "$install_test_dir"

# Copy and verification failures leave no destination, staging directory, or lock.
for failing_copy_tool in /usr/bin/false /usr/bin/true; do
    if INSTALL_DIR="$install_test_dir" COPY_TOOL="$failing_copy_tool" SKIP_REGISTRATION=1 \
        "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
        echo "Installer ignored a copy or staged-verification failure" >&2
        exit 1
    fi
    [[ ! -e "$install_test_dir/FinderCreateFile.app" ]]
    [[ ! -e "$install_test_dir/.FinderCreateFile.install.lock" ]]
    [[ -z "$(/usr/bin/find "$install_test_dir" -maxdepth 1 -name '.FinderCreateFile.stage.*' -print -quit)" ]]
done

# Catchable signals before final placement clean only temporary work.
for signal_name in INT TERM HUP; do
    if INSTALL_DIR="$install_test_dir" AFTER_COPY_SIGNAL="$signal_name" SKIP_REGISTRATION=1 \
        "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
        echo "Installer did not fail after $signal_name" >&2
        exit 1
    fi
    [[ ! -e "$install_test_dir/FinderCreateFile.app" ]]
    [[ ! -e "$install_test_dir/.FinderCreateFile.install.lock" ]]
    [[ -z "$(/usr/bin/find "$install_test_dir" -maxdepth 1 -name '.FinderCreateFile.stage.*' -print -quit)" ]]
done
if INSTALL_DIR="$install_test_dir" AFTER_COPY_SIGNAL=KILL SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
    echo "Installer accepted an unsafe signal test hook" >&2
    exit 1
fi
[[ ! -e "$install_test_dir/FinderCreateFile.app" ]]
[[ ! -e "$install_test_dir/.FinderCreateFile.install.lock" ]]
[[ -z "$(/usr/bin/find "$install_test_dir" -maxdepth 1 -name '.FinderCreateFile.stage.*' -print -quit)" ]]

# A non-cooperating process winning the destination race is preserved; the
# staged app is not nested into it and registration is never attempted.
collision_install_dir="$PROJECT_DIR/.build/install-target-race-test"
rm -rf "$collision_install_dir"
mkdir -p "$collision_install_dir"
if INSTALL_DIR="$collision_install_dir" BEFORE_FINAL_MOVE_TEST_HOOK=create-collision \
    LSREGISTER=/usr/bin/true PLUGIN_KIT=/usr/bin/true PROCESS_KILLER=/usr/bin/true \
    FINDER_RESTARTER=/usr/bin/true "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
    echo "Installer accepted a destination-path collision" >&2
    exit 1
fi
[[ -f "$collision_install_dir/FinderCreateFile.app/external-evidence" ]]
[[ ! -e "$collision_install_dir/FinderCreateFile.app/FinderCreateFile.app" ]]
[[ ! -e "$collision_install_dir/.FinderCreateFile.install.lock" ]]
[[ -z "$(/usr/bin/find "$collision_install_dir" -maxdepth 1 -name '.FinderCreateFile.stage.*' -print -quit)" ]]
rm -rf "$collision_install_dir"

# A stale lock is reported and preserved for deliberate manual inspection.
mkdir -p "$install_test_dir/.FinderCreateFile.install.lock"
echo 99999999 > "$install_test_dir/.FinderCreateFile.install.lock/owner.pid"
echo evidence > "$install_test_dir/.FinderCreateFile.install.lock/evidence"
if INSTALL_DIR="$install_test_dir" SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
    echo "Installer ignored a stale lock" >&2
    exit 1
fi
[[ -f "$install_test_dir/.FinderCreateFile.install.lock/evidence" ]]
[[ ! -e "$install_test_dir/FinderCreateFile.app" ]]
rm -rf "$install_test_dir/.FinderCreateFile.install.lock"

# Registration failure preserves the complete app for a safe retry.
if INSTALL_DIR="$install_test_dir" LSREGISTER=/usr/bin/false \
    PROCESS_KILLER=/usr/bin/true FINDER_RESTARTER=/usr/bin/true \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
    echo "Fresh install did not surface a registration failure" >&2
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$install_test_dir/FinderCreateFile.app"
[[ ! -e "$install_test_dir/.FinderCreateFile.install.lock" ]]
[[ -z "$(/usr/bin/find "$install_test_dir" -maxdepth 1 -name '.FinderCreateFile.stage.*' -print -quit)" ]]

# An identical build skips copying and only retries registration.
INSTALL_DIR="$install_test_dir" COPY_TOOL=/usr/bin/false LSREGISTER=/usr/bin/true \
    PLUGIN_KIT=/usr/bin/true PROCESS_KILLER=/usr/bin/true FINDER_RESTARTER=/usr/bin/true \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null
/usr/bin/codesign --verify --deep --strict "$install_test_dir/FinderCreateFile.app"

# A different, validly signed build is never overwritten automatically.
/usr/bin/plutil -replace CFBundleVersion -string 999 "$install_test_dir/FinderCreateFile.app/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$install_test_dir/FinderCreateFile.app" >/dev/null
different_cdhash="$(/usr/bin/codesign -dvvv "$install_test_dir/FinderCreateFile.app" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -1)"
source_cdhash="$(/usr/bin/codesign -dvvv "$APP" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -1)"
[[ "$different_cdhash" != "$source_cdhash" ]]
if INSTALL_DIR="$install_test_dir" SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
    echo "Installer overwrote a different build" >&2
    exit 1
fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$install_test_dir/FinderCreateFile.app/Contents/Info.plist")" == 999 ]]
[[ ! -e "$install_test_dir/.FinderCreateFile.install.lock" ]]
rm -rf "$install_test_dir/FinderCreateFile.app"

# Fresh success leaves one verified app and no staging residue.
INSTALL_DIR="$install_test_dir" SKIP_REGISTRATION=1 "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null
/usr/bin/codesign --verify --deep --strict "$install_test_dir/FinderCreateFile.app"
[[ ! -e "$install_test_dir/FinderCreateFile.app/FinderCreateFile.app" ]]
[[ ! -e "$install_test_dir/.FinderCreateFile.install.lock" ]]

# mkdir is the only concurrency lock; a second installer is rejected.
concurrent_install_dir="$PROJECT_DIR/.build/install-concurrent-test"
rm -rf "$concurrent_install_dir"
mkdir -p "$concurrent_install_dir"
INSTALL_DIR="$concurrent_install_dir" LOCK_HOLD_SECONDS=2 SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1 &
first_install_pid=$!
for _ in {1..50}; do
    [[ -e "$concurrent_install_dir/.FinderCreateFile.install.lock/owner.pid" ]] && break
    /bin/sleep 0.1
done
[[ -e "$concurrent_install_dir/.FinderCreateFile.install.lock/owner.pid" ]]
if INSTALL_DIR="$concurrent_install_dir" SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null 2>&1; then
    echo "Concurrent installer unexpectedly acquired the lock" >&2
    exit 1
fi
wait "$first_install_pid"
/usr/bin/codesign --verify --deep --strict "$concurrent_install_dir/FinderCreateFile.app"
[[ ! -e "$concurrent_install_dir/.FinderCreateFile.install.lock" ]]

support_test_dir="$PROJECT_DIR/.build/support-test"
trash_test_dir="$PROJECT_DIR/.build/trash-test"
mkdir -p "$support_test_dir"
echo '{"version":1,"enabledTypeIDs":["json"]}' > "$support_test_dir/settings.json"
INSTALL_DIR="$install_test_dir" SUPPORT_DIRECTORY="$support_test_dir" TRASH_DIR="$trash_test_dir" SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/uninstall.sh" --yes
[[ ! -e "$install_test_dir/FinderCreateFile.app" ]]
[[ -f "$support_test_dir/settings.json" ]]
INSTALL_DIR="$install_test_dir" SKIP_REGISTRATION=1 "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null
INSTALL_DIR="$install_test_dir" SUPPORT_DIRECTORY="$support_test_dir" TRASH_DIR="$trash_test_dir" SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/uninstall.sh" --yes --purge
[[ ! -e "$install_test_dir/FinderCreateFile.app" ]]
[[ ! -e "$support_test_dir" ]]
/usr/bin/find "$trash_test_dir" -name 'FinderCreateFile*.app' -print -quit | /usr/bin/grep -q .
/usr/bin/find "$trash_test_dir" -name 'FinderCreateFile-Settings-*' -print -quit | /usr/bin/grep -q .

collision_timestamp="20200101-000000"
collision_trash_dir="$PROJECT_DIR/.build/trash-collision-test"
collision_support_dir="$PROJECT_DIR/.build/support-collision-test"
rm -rf "$collision_trash_dir" "$collision_support_dir"
mkdir -p \
    "$collision_trash_dir/FinderCreateFile.app" \
    "$collision_trash_dir/FinderCreateFile-$collision_timestamp.app" \
    "$collision_trash_dir/FinderCreateFile-$collision_timestamp-2.app" \
    "$collision_trash_dir/FinderCreateFile-Settings-$collision_timestamp" \
    "$collision_trash_dir/FinderCreateFile-Settings-$collision_timestamp-2" \
    "$collision_support_dir"
INSTALL_DIR="$install_test_dir" SKIP_REGISTRATION=1 "$PROJECT_DIR/scripts/install.sh" "$APP" >/dev/null
echo 'collision-app-marker' > "$install_test_dir/FinderCreateFile.app/collision-app-marker"
echo 'collision-settings-marker' > "$collision_support_dir/collision-settings-marker"
INSTALL_DIR="$install_test_dir" SUPPORT_DIRECTORY="$collision_support_dir" TRASH_DIR="$collision_trash_dir" \
    TRASH_TIMESTAMP="$collision_timestamp" SKIP_REGISTRATION=1 \
    "$PROJECT_DIR/scripts/uninstall.sh" --yes --purge >/dev/null
[[ -f "$collision_trash_dir/FinderCreateFile-$collision_timestamp-3.app/collision-app-marker" ]]
[[ -f "$collision_trash_dir/FinderCreateFile-Settings-$collision_timestamp-3/collision-settings-marker" ]]
[[ ! -e "$collision_trash_dir/FinderCreateFile-$collision_timestamp-2.app/FinderCreateFile.app" ]]
[[ ! -e "$collision_trash_dir/FinderCreateFile-Settings-$collision_timestamp-2/support-collision-test" ]]
rm -rf "$install_test_dir"

echo "All verification checks passed."
