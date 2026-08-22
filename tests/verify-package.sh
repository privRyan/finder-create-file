#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.1.0"
PACKAGE_NAME="FinderCreateFile-v$VERSION-macos-universal"
ZIP_PATH="$PROJECT_DIR/dist/$PACKAGE_NAME.zip"

VERSION="$VERSION" BUILD_NUMBER=3 "$PROJECT_DIR/scripts/package.sh"
first_hash="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
VERSION="$VERSION" BUILD_NUMBER=3 "$PROJECT_DIR/scripts/package.sh"
second_hash="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
[[ "$first_hash" == "$second_hash" ]]

/usr/bin/unzip -tq "$ZIP_PATH"
entries="$(/usr/bin/unzip -Z1 "$ZIP_PATH")"
if /usr/bin/grep -q '__MACOSX\|\.DS_Store\|^/' <<< "$entries"; then
    echo "Package contains sidecar metadata or an absolute path" >&2
    exit 1
fi
for required in \
    'FinderCreateFile.app/Contents/Info.plist' \
    'Quick Start.md' CHANGELOG.md SECURITY.md LICENSE; do
    /usr/bin/grep -qx "$PACKAGE_NAME/$required" <<< "$entries"
done

extract_directory="$PROJECT_DIR/.build/package-check"
rm -rf "$extract_directory"
mkdir -p "$extract_directory"
/usr/bin/ditto -x -k "$ZIP_PATH" "$extract_directory"
package_directory="$extract_directory/$PACKAGE_NAME"
app="$package_directory/FinderCreateFile.app"
appex="$app/Contents/PlugIns/FinderCreateFileFinderSync.appex"

actual_top_level="$(/usr/bin/find "$package_directory" -mindepth 1 -maxdepth 1 -print | /usr/bin/sed 's|.*/||' | LC_ALL=C /usr/bin/sort)"
expected_top_level="$(/usr/bin/printf '%s\n' \
    CHANGELOG.md FinderCreateFile.app LICENSE 'Quick Start.md' SECURITY.md \
    '卸载 FinderCreateFile.command' '安装 FinderCreateFile.command' '快速使用说明.md' | LC_ALL=C /usr/bin/sort)"
[[ "$actual_top_level" == "$expected_top_level" ]]

/usr/bin/codesign --verify --deep --strict "$app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "3" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$appex/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$appex/Contents/Info.plist")" == "3" ]]
for executable in \
    "$app/Contents/MacOS/FinderCreateFile" \
    "$appex/Contents/MacOS/FinderCreateFileFinderSync"; do
    archs="$(/usr/bin/lipo -archs "$executable")"
    /usr/bin/grep -q 'arm64 x86_64\|x86_64 arm64' <<< "$archs"
    /usr/bin/grep -q 'minos 13.0' <<< "$(/usr/bin/vtool -show-build "$executable")"
done

for template in blank.docx blank.xlsx blank.pptx; do
    /usr/bin/unzip -tq "$app/Contents/Resources/Templates/$template"
done
pptx_entries="$(/usr/bin/unzip -Z1 "$app/Contents/Resources/Templates/blank.pptx")"
/usr/bin/grep -qx 'ppt/presentation.xml' <<< "$pptx_entries"
/usr/bin/grep -qx 'ppt/slides/slide1.xml' <<< "$pptx_entries"
if /usr/bin/unzip -p "$app/Contents/Resources/Templates/blank.pptx" ppt/slides/slide1.xml | \
   /usr/bin/grep -q '<p:sp[ >]\|<p:graphicFrame[ >]\|<p:pic[ >]\|<p:cxnSp[ >]'; then
    echo "Packaged PowerPoint template is not blank" >&2
    exit 1
fi
if /usr/bin/grep -Ei 'xcode-select|swiftc|clang|spctl[[:space:]].*--master-disable|xattr[[:space:]].*-d.*quarantine' \
    "$package_directory/安装 FinderCreateFile.command"; then
    echo "Packaged installer requires build tools or bypasses Gatekeeper" >&2
    exit 1
fi
if /usr/bin/grep -R -n --include='*.md' --include='*.command' --include='*.plist' \
    '/Users/' "$package_directory"; then
    echo "Package contains an absolute user path" >&2
    exit 1
fi
if /usr/bin/grep -R -E -n --include='*.md' --include='*.command' --include='*.plist' \
    'gh[opsu]_[A-Za-z0-9]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "$package_directory"; then
    echo "Package contains a credential-like value" >&2
    exit 1
fi

# The packaged commands install and uninstall without Command Line Tools or real system registration.
isolated_root="$PROJECT_DIR/.build/package-install-test"
install_dir="$isolated_root/Applications"
trash_dir="$isolated_root/Trash"
support_dir="$isolated_root/Container"
rm -rf "$isolated_root"
mkdir -p "$install_dir" "$trash_dir" "$support_dir"
echo preserve > "$support_dir/settings"
INSTALL_DIR="$install_dir" SKIP_REGISTRATION=1 "$package_directory/安装 FinderCreateFile.command" >/dev/null
/usr/bin/codesign --verify --deep --strict "$install_dir/FinderCreateFile.app"
INSTALL_DIR="$install_dir" SUPPORT_DIRECTORY="$support_dir" TRASH_DIR="$trash_dir" SKIP_REGISTRATION=1 \
    "$package_directory/卸载 FinderCreateFile.command" --yes >/dev/null
[[ ! -e "$install_dir/FinderCreateFile.app" && -f "$support_dir/settings" ]]
INSTALL_DIR="$install_dir" SKIP_REGISTRATION=1 "$package_directory/安装 FinderCreateFile.command" >/dev/null
INSTALL_DIR="$install_dir" SUPPORT_DIRECTORY="$support_dir" LEGACY_DATA_DIRECTORY="$isolated_root/no-legacy" \
    TRASH_DIR="$trash_dir" SKIP_REGISTRATION=1 "$package_directory/卸载 FinderCreateFile.command" --yes --purge >/dev/null
[[ ! -e "$install_dir/FinderCreateFile.app" && ! -e "$support_dir" ]]

echo "Deterministic universal package verification passed: $first_hash"
